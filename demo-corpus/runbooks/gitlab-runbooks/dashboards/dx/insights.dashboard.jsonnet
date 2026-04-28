local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local template = grafana.template;

// ============================================================================
// Template variables
// ============================================================================

local granularityTemplate = template.custom(
  'granularity',
  'group,stage,section',
  'group',
);

// ============================================================================
// SQL helpers
// ============================================================================

// Uses shared.category_owners (71 groups) instead of code_coverage.category_owners (69 groups)
// for more complete group-to-stage-to-section coverage
local categoryOwnersTable = '"shared"."category_owners"';
local issueMetricsTable = '"work_item_metrics"."issue_metrics"';

// Deduplicated issue_metrics subquery using argMax to get latest state per issue.
// The table has `state` in its ORDER BY key, so FINAL keeps both opened and closed
// rows for the same issue. argMax(col, updated_at) grouped by id gives the true latest.
local issueMetricsDedup =
  '(\n' +
  '  SELECT\n' +
  '    id,\n' +
  '    argMax(project_path, updated_at) AS project_path,\n' +
  '    argMax(state, updated_at) AS state,\n' +
  '    argMax(labels, updated_at) AS labels,\n' +
  '    argMax(created_at, updated_at) AS created_at,\n' +
  '    argMax(milestone_id, updated_at) AS milestone_id\n' +
  '  FROM ' + issueMetricsTable + '\n' +
  '  GROUP BY id\n' +
  ')';
local testRuntimeTable = '"test_metrics"."test_results_passed_test_file_runtime"';
local quarantinedTestsMv = '"test_metrics"."quarantined_tests_hourly_mv"';
local testFileRiskSummary = '"code_coverage"."test_file_risk_summary"';

// Flaky test classification thresholds (must match flaky-tests-overview.dashboard.jsonnet)
local FLAKY_MIN_PIPELINES = 10;
local FLAKY_SPIKE_THRESHOLD_MIN = 30;
local FLAKY_SPIKE_CONCENTRATION_PCT = 40;
local FLAKY_SPIKE_ABSOLUTE = 60;
local FLAKY_MIN_FAILURE_DAYS = 3;
local FLAKY_MAX_DAYS_SINCE_LAST = 3;

// Classification CTE for flaky test detection, ported from flaky-tests-overview
// with hardcoded 7-day window and gitlab-org/gitlab project scope
local flakyClassificationCte =
  'file_metrics AS (\n'
  + '  SELECT\n'
  + '    btf.file_path,\n'
  + '    any(btf.`group`) as `group`,\n'
  + '    COUNT(DISTINCT btf.ci_pipeline_id) as total_pipelines,\n'
  + '    COUNT(DISTINCT btf.failure_date) as failure_days,\n'
  + "    dateDiff('day', MAX(btf.failure_date), toDate(now())) as days_since_last\n"
  + '  FROM test_metrics.blocking_test_failures_mv btf\n'
  + '  INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\n'
  + "  WHERE btf.ci_project_path = 'gitlab-org/gitlab'\n"
  + '    AND btf.timestamp >= now() - INTERVAL 7 DAY\n'
  + '    AND btf.timestamp <= now()\n'
  + '    AND bm.allow_failure = false\n'
  + "    AND bm.status = 'failed'\n"
  + '  GROUP BY btf.file_path\n'
  + '),\n'
  + 'windowed AS (\n'
  + '  SELECT\n'
  + '    btf.file_path,\n'
  + '    toStartOfInterval(btf.timestamp, INTERVAL 12 HOUR) as window,\n'
  + '    COUNT(DISTINCT btf.ci_pipeline_id) as pipelines_in_window\n'
  + '  FROM test_metrics.blocking_test_failures_mv btf\n'
  + '  INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\n'
  + "  WHERE btf.ci_project_path = 'gitlab-org/gitlab'\n"
  + '    AND btf.timestamp >= now() - INTERVAL 7 DAY\n'
  + '    AND btf.timestamp <= now()\n'
  + '    AND bm.allow_failure = false\n'
  + "    AND bm.status = 'failed'\n"
  + '  GROUP BY btf.file_path, window\n'
  + '),\n'
  + 'clustered AS (\n'
  + '  SELECT\n'
  + '    file_path,\n'
  + '    MAX(pipelines_in_window) as max_in_12h\n'
  + '  FROM windowed\n'
  + '  GROUP BY file_path\n'
  + '),\n'
  + 'file_classifications AS (\n'
  + '  SELECT\n'
  + '    fm.file_path,\n'
  + '    fm.`group`,\n'
  + '    CASE\n'
  + '      WHEN c.max_in_12h >= ' + std.toString(FLAKY_SPIKE_THRESHOLD_MIN) + '\n'
  + '        AND (\n'
  + '          round(c.max_in_12h * 100.0 / fm.total_pipelines, 1) >= ' + std.toString(FLAKY_SPIKE_CONCENTRATION_PCT) + '\n'
  + '          OR c.max_in_12h >= ' + std.toString(FLAKY_SPIKE_ABSOLUTE) + '\n'
  + '        )\n'
  + "        THEN 'master_broken'\n"
  + '      WHEN fm.failure_days >= ' + std.toString(FLAKY_MIN_FAILURE_DAYS) + '\n'
  + '        AND fm.days_since_last <= ' + std.toString(FLAKY_MAX_DAYS_SINCE_LAST) + '\n'
  + "        THEN 'flaky'\n"
  + "      ELSE 'unclear'\n"
  + '    END as classification\n'
  + '  FROM file_metrics fm\n'
  + '  INNER JOIN clustered c ON fm.file_path = c.file_path\n'
  + '  WHERE fm.total_pipelines >= ' + std.toString(FLAKY_MIN_PIPELINES) + '\n'
  + ')';

local granularityColumn =
  "replaceAll(IF('${granularity}' = 'group', co.\"group\",\n" +
  "  IF('${granularity}' = 'stage', co.stage, co.section)\n" +
  "), '_', ' ') AS name";

local groupFromLabels =
  "replaceAll(replaceOne(arrayFirst(x -> startsWith(x, 'group::'), labels), 'group::', ''), ' ', '_')";

local issueMetricSubquery(labelFilters, condition, columnName) =
  'SELECT\n' +
  '  ' + groupFromLabels + ' AS grp,\n' +
  '  countIf(\n' +
  '    ' + condition + '\n' +
  '  ) AS ' + columnName + '\n' +
  'FROM ' + issueMetricsDedup + '\n' +
  "WHERE project_path = 'gitlab-org/gitlab'\n" +
  "  AND state = 'opened'\n" +
  '  AND ' + std.join('\n  AND ', labelFilters) + '\n' +
  'GROUP BY grp';

local indent(sql) = std.strReplace(sql, '\n', '\n  ');

local categoryOwnersDedupSubquery =
  'SELECT DISTINCT "group", stage, section\n' +
  'FROM ' + categoryOwnersTable;

// Helper to build a sum(COALESCE(...)) column
local col(alias, table, field=null) =
  '  sum(COALESCE(' + table + '.' + (if field != null then field else alias) + ', 0)) AS ' + alias;

// Builds a complete section query from column expressions and JOIN clauses
// raw_name keeps the underscore format for DX dashboard drill-down links
local rawNameColumn =
  "IF('${granularity}' = 'group', co.\"group\",\n" +
  "  IF('${granularity}' = 'stage', co.stage, co.section)\n" +
  ') AS raw_name';

local sectionQuery(columns, joins) =
  'SELECT\n' +
  '  ' + granularityColumn + ',\n' +
  '  ' + rawNameColumn + ',\n' +
  std.join(',\n', columns) + '\n' +
  'FROM (\n' +
  '  ' + indent(categoryOwnersDedupSubquery) + '\n' +
  ') co\n' +
  std.join('\n', joins) + '\n' +
  'GROUP BY name, raw_name\n' +
  "HAVING name IS NOT NULL AND name != ''\n" +
  'ORDER BY name ASC';

// GitLab work_items URL builder for drill-down links
local workItemsUrl(labelParams, notLabelParams=[]) =
  'https://gitlab.com/groups/gitlab-org/-/work_items?sort=created_asc&state=opened&' +
  std.join('&', [
    'label_name%5B%5D=' + l
    for l in labelParams
  ]) +
  '&label_name%5B%5D=group%3A%3A${__data.fields.name:percentencode}' +
  '&not%5Btype%5D%5B%5D=EPIC' +
  std.join('', [
    '&not%5Blabel_name%5D%5B%5D=' + l
    for l in notLabelParams
  ]);

local bugUrl(extraLabels=[], notLabels=[]) =
  workItemsUrl(['type%3A%3Abug'] + extraLabels, notLabels);

// DX dashboard drill-down URL builder
// Passes var-group filter. If the target dashboard doesn't support it, the param is ignored.
local dxDashUrl(filename, timeRange='') =
  '/d/' + config.uid(filename) +
  '?var-group=${__data.fields.raw_name:percentencode}' +
  (if timeRange != '' then '&from=' + timeRange + '&to=now' else '');

// ============================================================================
// SLO-backed domain subqueries
// ============================================================================

local securitySubquery = issueMetricSubquery(
  ["has(labels, 'bug::vulnerability')"],
  "(arrayFirst(x -> startsWith(x, 'severity::'), labels) IN ('severity::1', 'severity::2')\n" +
  "      AND dateDiff('day', created_at, now()) >= 30)\n" +
  "    OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::3'\n" +
  "      AND dateDiff('day', created_at, now()) >= 90)\n" +
  "    OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::4'\n" +
  "      AND dateDiff('day', created_at, now()) >= 180)",
  'security_past_sla',
);

local availabilitySubquery = issueMetricSubquery(
  ["has(labels, 'type::bug')", "has(labels, 'bug::availability')"],
  "(arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::1'\n" +
  "      AND dateDiff('day', created_at, now()) >= 2)\n" +
  "    OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::2'\n" +
  "      AND dateDiff('day', created_at, now()) >= 7)\n" +
  "    OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::3'\n" +
  "      AND dateDiff('day', created_at, now()) >= 30)\n" +
  "    OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::4'\n" +
  "      AND dateDiff('day', created_at, now()) >= 60)",
  'availability_past_sla',
);

local infradevSubquery = issueMetricSubquery(
  ["has(labels, 'infradev')"],
  "(arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::1'\n" +
  "      AND dateDiff('day', created_at, now()) >= 30)\n" +
  "    OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::2'\n" +
  "      AND dateDiff('day', created_at, now()) >= 60)\n" +
  "    OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::3'\n" +
  "      AND dateDiff('day', created_at, now()) >= 90)\n" +
  "    OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::4'\n" +
  "      AND dateDiff('day', created_at, now()) >= 120)",
  'infradev_past_sla',
);

// ============================================================================
// Test-metric domain subqueries
// ============================================================================

local testDurationSubquery =
  'SELECT\n' +
  '  "group" AS grp,\n' +
  '  count() AS test_duration_amber\n' +
  'FROM (\n' +
  '  SELECT "group", run_type, file_path, avg_file_runtime,\n' +
  '    ROW_NUMBER() OVER (\n' +
  '      PARTITION BY "group", run_type, file_path\n' +
  '      ORDER BY timestamp DESC\n' +
  '    ) AS rn\n' +
  '  FROM ' + testRuntimeTable + '\n' +
  '  WHERE timestamp >= now() - INTERVAL 7 DAY\n' +
  "    AND ci_project_path = 'gitlab-org/gitlab'\n" +
  "    AND run_type IN ('gitlab-rspec-tests', 'e2e-test-on-gdk')\n" +
  "    AND \"group\" != ''\n" +
  ') WHERE rn = 1\n' +
  "  AND ((run_type = 'gitlab-rspec-tests' AND avg_file_runtime >= 120)\n" +
  "    OR (run_type = 'e2e-test-on-gdk' AND avg_file_runtime >= 300))\n" +
  'GROUP BY grp';

local flakyTestsSubquery =
  'WITH\n' + flakyClassificationCte + '\n' +
  'SELECT\n' +
  '  `group` AS grp,\n' +
  '  COUNT(DISTINCT file_path) AS flaky_tests_count\n' +
  'FROM file_classifications\n' +
  "WHERE classification = 'flaky'\n" +
  "  AND `group` != '' AND `group` != 'unknown'\n" +
  'GROUP BY grp';

// ============================================================================
// Attention-filtered domain subqueries
// ============================================================================

// Deferred UX: open bug::ux issues needing attention per triage policy.
// Three attention criteria (from triage-ops lib/sections/deferred_ux.rb):
//   1. Missing severity label
//   2. Missing priority label
//   3. Severity too high (S1/S2) -- handbook states deferred UX should not exceed S3
local deferredUxSubquery = issueMetricSubquery(
  ["has(labels, 'bug::ux')"],
  "NOT hasAny(labels, ['severity::1','severity::2','severity::3','severity::4'])\n" +
  "    OR NOT hasAny(labels, ['priority::1','priority::2','priority::3'])\n" +
  "    OR hasAny(labels, ['severity::1','severity::2'])",
  'deferred_ux_attention',
);

local quarantineSubquery =
  'SELECT\n' +
  '  "group" AS grp,\n' +
  '  uniqIf(file_path, location,\n' +
  "    issue_url IS NULL OR issue_url = ''\n" +
  '    OR min_seen <= now() - INTERVAL 30 DAY\n' +
  '  ) AS quarantine_attention\n' +
  'FROM (\n' +
  '  SELECT "group", file_path, location, any(issue_url) AS issue_url,\n' +
  '    min(hour_timestamp) AS min_seen\n' +
  '  FROM ' + quarantinedTestsMv + '\n' +
  '  WHERE hour_timestamp >= now() - INTERVAL 90 DAY\n' +
  "    AND project_path = 'gitlab-org/gitlab'\n" +
  "    AND \"group\" != ''\n" +
  '  GROUP BY "group", file_path, location\n' +
  '  HAVING max(hour_timestamp) >= now() - INTERVAL 7 DAY\n' +
  ')\n' +
  'GROUP BY grp';

local coverageRiskSubquery =
  'SELECT\n' +
  '  q."group" AS grp,\n' +
  '  uniqIf(q.file_path, q.location,\n' +
  "    r.risk_level IN ('CRITICAL', 'HIGH')\n" +
  '  ) AS coverage_risk_count\n' +
  'FROM ' + quarantinedTestsMv + ' q\n' +
  'LEFT JOIN ' + testFileRiskSummary + ' r FINAL\n' +
  '  ON q.file_path = r.test_file\n' +
  "  AND r.ci_project_path = 'gitlab-org/gitlab'\n" +
  'WHERE q.hour_timestamp >= now() - INTERVAL 12 HOUR\n' +
  "  AND q.project_path = 'gitlab-org/gitlab'\n" +
  "  AND q.\"group\" != ''\n" +
  'GROUP BY grp';

// ============================================================================
// Count-only domain subqueries
// ============================================================================

local bugCountsSubquery =
  'SELECT\n' +
  '  ' + groupFromLabels + ' AS grp,\n' +
  '  count() AS bugs_all,\n' +
  "  countIf(has(labels, 'customer')) AS bugs_customer,\n" +
  "  countIf(has(labels, 'frontend') AND has(labels, 'customer')\n" +
  '    AND milestone_id IS NULL) AS bugs_fe_customer,\n' +
  "  countIf(has(labels, 'frontend') AND NOT has(labels, 'customer')\n" +
  '    AND milestone_id IS NULL) AS bugs_fe,\n' +
  "  countIf(NOT has(labels, 'frontend') AND has(labels, 'customer')\n" +
  '    AND milestone_id IS NULL) AS bugs_be_customer,\n' +
  "  countIf(NOT has(labels, 'frontend') AND NOT has(labels, 'customer')\n" +
  '    AND milestone_id IS NULL) AS bugs_be,\n' +
  "  countIf(has(labels, 'SLO::Missed')) AS bugs_past_slo,\n" +
  "  countIf(has(labels, 'vintage')) AS bugs_vintage,\n" +
  "  countIf(has(labels, 'workflow::blocked')) AS bugs_blocked\n" +
  'FROM ' + issueMetricsDedup + '\n' +
  "WHERE project_path = 'gitlab-org/gitlab'\n" +
  "  AND state = 'opened'\n" +
  "  AND has(labels, 'type::bug')\n" +
  "  AND NOT has(labels, 'security_auto_triage')\n" +
  'GROUP BY grp';

local featureProposalsSubquery =
  'SELECT\n' +
  '  ' + groupFromLabels + ' AS grp,\n' +
  "  countIf(has(labels, 'customer') AND milestone_id IS NULL) AS feat_customer,\n" +
  "  countIf(NOT has(labels, 'customer') AND milestone_id IS NULL) AS feat_non_customer\n" +
  'FROM ' + issueMetricsDedup + '\n' +
  "WHERE project_path = 'gitlab-org/gitlab'\n" +
  "  AND state = 'opened'\n" +
  "  AND has(labels, 'type::feature')\n" +
  'GROUP BY grp';

local communitySubquery =
  'SELECT\n' +
  '  ' + groupFromLabels + ' AS grp,\n' +
  '  count() AS community_untriaged\n' +
  'FROM ' + issueMetricsDedup + '\n' +
  "WHERE project_path = 'gitlab-org/gitlab'\n" +
  "  AND state = 'opened'\n" +
  "  AND NOT has(labels, 'type::feature')\n" +
  "  AND NOT has(labels, 'type::bug')\n" +
  "  AND NOT has(labels, 'type::maintenance')\n" +
  '  AND created_at >= now() - INTERVAL 7 DAY\n' +
  'GROUP BY grp';

// ============================================================================
// Section queries
// ============================================================================

local joinClause(subquery, alias) =
  'LEFT JOIN (\n  ' + indent(subquery) + '\n) ' + alias + ' ON co."group" = ' + alias + '.grp';

// Issues Past SLA: issues needing action (past SLA + deferred UX)
local sloAttentionQuery = sectionQuery(
  [col('security_past_sla', 'sec'), col('availability_past_sla', 'avail'), col('infradev_past_sla', 'infra'), col('deferred_ux_attention', 'dux')],
  [joinClause(securitySubquery, 'sec'), joinClause(availabilitySubquery, 'avail'), joinClause(infradevSubquery, 'infra'), joinClause(deferredUxSubquery, 'dux')],
);

// Test Health: test infrastructure metrics
local testHealthQuery = sectionQuery(
  [col('flaky_tests_count', 'ft'), col('quarantine_attention', 'qt'), col('test_duration_amber', 'td'), col('coverage_risk_count', 'cr')],
  [joinClause(flakyTestsSubquery, 'ft'), joinClause(quarantineSubquery, 'qt'), joinClause(testDurationSubquery, 'td'), joinClause(coverageRiskSubquery, 'cr')],
);

local bugsQuery = sectionQuery(
  [col('bugs_all', 'bugs'), col('bugs_past_slo', 'bugs'), col('bugs_customer', 'bugs'), col('bugs_fe_customer', 'bugs'), col('bugs_fe', 'bugs'), col('bugs_be_customer', 'bugs'), col('bugs_be', 'bugs'), col('bugs_blocked', 'bugs'), col('bugs_vintage', 'bugs')],
  [joinClause(bugCountsSubquery, 'bugs')],
);

local proposalsQuery = sectionQuery(
  [col('feat_customer', 'fp'), col('feat_non_customer', 'fp'), col('community_untriaged', 'comm')],
  [joinClause(featureProposalsSubquery, 'fp'), joinClause(communitySubquery, 'comm')],
);

// ============================================================================
// Panel overrides
// ============================================================================

local domainColumnOverride(fieldName, displayName, linkTitle, linkUrl) = {
  matcher: { id: 'byName', options: fieldName },
  properties: [
    { id: 'displayName', value: displayName },
    { id: 'min', value: 1 },
    { id: 'color', value: { mode: 'continuous-GrYlRd' } },
    { id: 'custom.cellOptions', value: { type: 'color-background', mode: 'gradient' } },
    {
      id: 'mappings',
      value: [{
        type: 'value',
        options: {
          '0': { text: '0', color: 'transparent', index: 0 },
        },
      }],
    },
    { id: 'custom.width', value: 150 },
  ] + (if linkUrl != '' then [{
         id: 'links',
         value: [{
           targetBlank: true,
           title: linkTitle,
           url: linkUrl,
         }],
       }] else []),
};

local nameColumnOverride = {
  matcher: { id: 'byName', options: 'name' },
  properties: [
    { id: 'displayName', value: '${granularity}' },
    { id: 'custom.width', value: 200 },
  ],
};

local rawNameHiddenOverride = {
  matcher: { id: 'byName', options: 'raw_name' },
  properties: [
    { id: 'custom.hidden', value: true },
  ],
};

// ============================================================================
// Table panel builder
// ============================================================================

local sectionTable(title, rawSql, overrides, gridPos) =
  panels.tablePanel(
    title=title,
    rawSql=rawSql,
    sortBy=[{ desc: false, displayName: '${granularity}' }],
    overrides=[nameColumnOverride, rawNameHiddenOverride] + overrides,
    description='Drill-down links filter by group:: label and are most useful at group granularity.',
  ) + {
    gridPos: gridPos,
  };

// ============================================================================
// Explanation text panels
// ============================================================================

local explanationPanel(title, content) = panels.textPanel(
  title=title,
  content=content,
) + {
  transparent: true,
};

// Colour constants for explanation panels
local c = {
  col: '#E0E0E0',  // column names (light silver)
  s1: '#F2495C',  // S1 severity (red)
  s2: '#FF9830',  // S2 severity (orange)
  s3: '#FADE2A',  // S3 severity (yellow)
  s4: '#73BF69',  // S4 severity (green)
  muted: '#999',  // footnotes
  label: '#CA95E5',  // label references (purple)
};
local cn(name) = '<span style="color:' + c.col + '">**' + name + '**</span>';
local sev(level, text) = '<span style="color:' + (if level == '1' then c.s1 else if level == '2' then c.s2 else if level == '3' then c.s3 else c.s4) + '">' + text + '</span>';
local lbl(text) = '<span style="color:' + c.label + '">`' + text + '`</span>';
local muted(text) = '<span style="color:' + c.muted + '">' + text + '</span>';

local sloExplanation = explanationPanel('', |||
  **Issues past their SLA deadline.**
  Counts are past-SLA only; click a cell to see all open issues.

  | Column | SLA Thresholds |
  |--------|---------------|
  | %(security)s | %(s1a)s %(s3a)s %(s4a)s |
  | %(availability)s | %(s1b)s %(s2b)s %(s3b)s %(s4b)s |
  | %(infradev)s | %(s1c)s %(s2c)s %(s3c)s %(s4c)s |
  | %(dux)s | Missing severity/priority or %(s1s2)s |

  %(footnote)s
||| % {
  security: cn('Security'),
  availability: cn('Availability'),
  infradev: cn('Infradev'),
  dux: cn('Deferred UX'),
  s1a: sev('1', 'S1/S2: 30d,'),
  s3a: sev('3', 'S3: 90d,'),
  s4a: sev('4', 'S4: 180d'),
  s1b: sev('1', 'S1: 2d,'),
  s2b: sev('2', 'S2: 7d,'),
  s3b: sev('3', 'S3: 30d,'),
  s4b: sev('4', 'S4: 60d'),
  s1c: sev('1', 'S1: 30d,'),
  s2c: sev('2', 'S2: 60d,'),
  s3c: sev('3', 'S3: 90d,'),
  s4c: sev('4', 'S4: 120d'),
  s1s2: sev('1', 'S1') + '/' + sev('2', 'S2'),
  footnote: muted('Infradev SLA uses created_at as proxy (label-added date unavailable).'),
});

local testHealthExplanation = explanationPanel('', |||
  **Test infrastructure health indicators.**
  Click a cell to drill down to the relevant DX dashboard.

  | Column | What it counts |
  |--------|---------------|
  | %(flaky)s | Test files classified as flaky in last 7 days |
  | %(quarantine)s | Missing tracking issue or quarantined > 30d |
  | %(duration)s | Files over amber threshold |
  | %(covrisk)s | Quarantined tests at %(critical)s/%(high)s risk |

  | Duration thresholds | |
  |--------|--------|
  | Backend RSpec | >= 2 min |
  | E2E | >= 5 min |
||| % {
  flaky: cn('Flaky'),
  quarantine: cn('Quarantine'),
  duration: cn('Duration'),
  covrisk: cn('Cov. Risk'),
  critical: sev('1', 'CRITICAL'),
  high: sev('2', 'HIGH'),
});

local bugsExplanation = explanationPanel('', |||
  **Open bug breakdown.** All filtered to %(bug)s, excluding %(excl)s.

  | Column | Filter |
  |--------|--------|
  | %(all)s | All open bugs |
  | %(slo)s | Has %(slolbl)s label |
  | %(cust)s | Has %(custlbl)s label |
  | %(fecust)s | %(felbl)s + %(custlbl)s, no milestone |
  | %(fe)s | %(felbl)s, no %(custlbl)s, no milestone |
  | %(becust)s | No %(felbl)s, has %(custlbl)s, no milestone |
  | %(be)s | No %(felbl)s, no %(custlbl)s, no milestone |
  | %(blocked)s | Has %(blockedlbl)s |
  | %(vintage)s | Has %(vintagelbl)s label |
||| % {
  bug: lbl('type::bug'),
  excl: lbl('security_auto_triage'),
  all: cn('All'),
  slo: cn('Missed SLO'),
  cust: cn('Customer'),
  fecust: cn('FE Cust.'),
  fe: cn('FE'),
  becust: cn('BE Cust.'),
  be: cn('BE'),
  blocked: cn('Blocked'),
  vintage: cn('Vintage'),
  slolbl: lbl('SLO::Missed'),
  custlbl: lbl('customer'),
  felbl: lbl('frontend'),
  blockedlbl: lbl('workflow::blocked'),
  vintagelbl: lbl('vintage'),
});

local proposalsExplanation = explanationPanel('', |||
  **Incoming work and community triage.**

  | Column | Filter |
  |--------|--------|
  | %(custfeat)s | %(featlbl)s + %(custlbl)s, no milestone |
  | %(feat)s | %(featlbl)s, no %(custlbl)s, no milestone |
  | %(community)s | No type label, created in last 7 days |

  %(footnote)s
||| % {
  custfeat: cn('Cust. Features'),
  feat: cn('Features'),
  community: cn('Community'),
  featlbl: lbl('type::feature'),
  custlbl: lbl('customer'),
  footnote: muted('Community count is approximate (cannot filter by author membership from ClickHouse).'),
});

// ============================================================================
// Section panels
// Layout:
//   Row 0: About (collapsed row with text panel)
//   Row 1: Stat panels (w=4 each, h=4)
//   Row 2: Highest Impact Groups (w=16, h=10) | Explanation (w=8)
//   Row 3-6: Collapsible detail sections
// ============================================================================

local aboutHeight = 1;
local statHeight = 4;
local offendersHeight = 10;
local tableHeight = 16;
local tableWidth = 16;
local explWidth = 8;

local aboutY = 0;
local statsY = aboutHeight;
local offendersY = statsY + statHeight;
local row1Y = offendersY + offendersHeight;

// ============================================================================
// Row 0: About this dashboard
// ============================================================================

local aboutText = explanationPanel('', (|||
                                          ## DX Insights

                                          Current health of GitLab engineering teams across triage report criteria. All data is live state. The time range picker has no effect.

                                          **Domain areas covered:**

                                          | Section | What it tracks |
                                          |---------|---------------|
                                          | **Issues Past SLA** | %(sec)s, %(avail)s, %(infra)s, and %(dux)s issues that have exceeded their handbook-defined SLA deadlines |
                                          | **Test Health** | %(flaky)s tests, %(qt)s tests needing attention, test file %(dur)s exceeding thresholds, and %(cr)s for quarantined tests |
                                          | **Bugs** | Open bug counts broken down by customer impact, frontend/backend, missed SLO, blocked, and vintage |
                                          | **Proposals & Community** | Unscheduled feature proposals (customer and non-customer) and untriaged community issues from the last 7 days |

                                          **Reading the dashboard:**
                                          - **Stat panels** at the top show org-wide totals
                                          - **Highest Impact Groups** ranks the top 10 groups by total issue count across all domains
                                          - **Collapsible sections** expand to show full per-group breakdowns with an explanation panel describing each column's filters
                                          - **Cell colours** use a green-to-red gradient scaled to the column's value range. Cells with 0 have no background.
                                          - **Click any cell** to drill down to the relevant issue list or DX dashboard

                                          **Granularity** controls row aggregation: **group**, **stage**, or **section**. Drill-down links filter by %(grouplbl)s label, so they work best at group level.

                                          **Data sources:** Issue counts from %(issues)s (current open state). Test metrics from ClickHouse materialized views (last 7 days). Group-to-stage-to-section hierarchy from %(owners)s.

                                          **Note:** Drill-down links for SLA columns (Security, Availability, Infradev, Deferred UX) show all matching open issues, not just those past SLA. GitLab's URL filters cannot express age-per-severity conditions, so the link results may exceed the cell count.
                                        ||| % {
                                          sec: cn('Security'),
                                          avail: cn('Availability'),
                                          infra: cn('Infradev'),
                                          dux: cn('Deferred UX'),
                                          flaky: cn('Flaky'),
                                          qt: cn('Quarantined'),
                                          dur: cn('Duration'),
                                          cr: cn('Coverage Risk'),
                                          grouplbl: lbl('group::'),
                                          issues: lbl('work_item_metrics.issue_metrics'),
                                          owners: lbl('shared.category_owners'),
                                        }));

local aboutRow = {
  type: 'row',
  title: 'About this dashboard',
  collapsed: true,
  gridPos: { h: 1, w: 24, x: 0, y: aboutY },
  panels: [
    aboutText { gridPos: { h: 10, w: 24, x: 0, y: aboutY + 1 } },
  ],
};
local row2Y = row1Y + tableHeight;
local row3Y = row2Y + tableHeight;
local row4Y = row3Y + tableHeight;

// ============================================================================
// Row 0: Stat panels - org-wide totals
// ============================================================================

local statSql(condition, labelFilters) =
  'SELECT countIf(' + condition + ') AS value\n' +
  'FROM ' + issueMetricsDedup + '\n' +
  "WHERE project_path = 'gitlab-org/gitlab'\n" +
  "  AND state = 'opened'\n" +
  '  AND ' + std.join('\n  AND ', labelFilters);

local securityStatSql = statSql(
  "(arrayFirst(x -> startsWith(x, 'severity::'), labels) IN ('severity::1', 'severity::2') AND dateDiff('day', created_at, now()) >= 30)" +
  " OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::3' AND dateDiff('day', created_at, now()) >= 90)" +
  " OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::4' AND dateDiff('day', created_at, now()) >= 180)",
  ["has(labels, 'bug::vulnerability')"],
);

local availabilityStatSql = statSql(
  "(arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::1' AND dateDiff('day', created_at, now()) >= 2)" +
  " OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::2' AND dateDiff('day', created_at, now()) >= 7)" +
  " OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::3' AND dateDiff('day', created_at, now()) >= 30)" +
  " OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::4' AND dateDiff('day', created_at, now()) >= 60)",
  ["has(labels, 'type::bug')", "has(labels, 'bug::availability')"],
);

local infradevStatSql = statSql(
  "(arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::1' AND dateDiff('day', created_at, now()) >= 30)" +
  " OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::2' AND dateDiff('day', created_at, now()) >= 60)" +
  " OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::3' AND dateDiff('day', created_at, now()) >= 90)" +
  " OR (arrayFirst(x -> startsWith(x, 'severity::'), labels) = 'severity::4' AND dateDiff('day', created_at, now()) >= 120)",
  ["has(labels, 'infradev')"],
);

local totalBugsStatSql =
  'SELECT count() AS value\n' +
  'FROM ' + issueMetricsDedup + '\n' +
  "WHERE project_path = 'gitlab-org/gitlab'\n" +
  "  AND state = 'opened'\n" +
  "  AND has(labels, 'type::bug')\n" +
  "  AND NOT has(labels, 'security_auto_triage')";

local flakyStatSql =
  'WITH\n' + flakyClassificationCte + '\n' +
  'SELECT COUNT(DISTINCT file_path) AS value\n' +
  'FROM file_classifications\n' +
  "WHERE classification = 'flaky'";

local quarantineStatSql =
  'SELECT uniqIf(file_path, location,\n' +
  "  issue_url IS NULL OR issue_url = ''\n" +
  '  OR min_seen <= now() - INTERVAL 30 DAY\n' +
  ') AS value\n' +
  'FROM (\n' +
  '  SELECT file_path, location, any(issue_url) AS issue_url,\n' +
  '    min(hour_timestamp) AS min_seen\n' +
  '  FROM ' + quarantinedTestsMv + '\n' +
  '  WHERE hour_timestamp >= now() - INTERVAL 90 DAY\n' +
  "    AND project_path = 'gitlab-org/gitlab'\n" +
  "    AND \"group\" != ''\n" +
  '  GROUP BY file_path, location\n' +
  '  HAVING max(hour_timestamp) >= now() - INTERVAL 7 DAY\n' +
  ')';

local statStyle = {
  fieldConfig+: { defaults+: { unit: 'locale' } },
};

local statPanels = [
  panels.statPanel(title='Security SLO', rawSql=securityStatSql, description='Vulnerability issues past SLA org-wide')
  + statStyle + { gridPos: { h: statHeight, w: 4, x: 0, y: statsY } },
  panels.statPanel(title='Availability SLO', rawSql=availabilityStatSql, description='Availability bugs past TTR SLO org-wide')
  + statStyle + { gridPos: { h: statHeight, w: 4, x: 4, y: statsY } },
  panels.statPanel(title='Infradev SLO', rawSql=infradevStatSql, description='Infradev issues past SLO org-wide')
  + statStyle + { gridPos: { h: statHeight, w: 4, x: 8, y: statsY } },
  panels.statPanel(title='Total Bugs', rawSql=totalBugsStatSql, description='All open bugs org-wide')
  + statStyle + { gridPos: { h: statHeight, w: 4, x: 12, y: statsY } },
  panels.statPanel(title='Flaky Tests', rawSql=flakyStatSql, description='Flaky test files in last 7 days')
  + statStyle + { gridPos: { h: statHeight, w: 4, x: 16, y: statsY } },
  panels.statPanel(title='Quarantine', rawSql=quarantineStatSql, description='Quarantined tests needing attention')
  + statStyle + { gridPos: { h: statHeight, w: 4, x: 20, y: statsY } },
];

// ============================================================================
// Row 1: Highest Impact Groups - top 10 groups by weighted attention score
// ============================================================================

local highestImpactQuery = sectionQuery(
  [
    col('security_past_sla', 'sec'),
    col('availability_past_sla', 'avail'),
    col('infradev_past_sla', 'infra'),
    col('deferred_ux_attention', 'dux'),
    col('flaky_tests_count', 'ft'),
    col('quarantine_attention', 'qt'),
    col('bugs_past_slo', 'bugs', 'bugs_past_slo'),
    '  sum(COALESCE(sec.security_past_sla, 0))\n' +
    '    + sum(COALESCE(avail.availability_past_sla, 0))\n' +
    '    + sum(COALESCE(infra.infradev_past_sla, 0))\n' +
    '    + sum(COALESCE(bugs.bugs_past_slo, 0))\n' +
    '    + sum(COALESCE(dux.deferred_ux_attention, 0))\n' +
    '    + sum(COALESCE(ft.flaky_tests_count, 0))\n' +
    '    + sum(COALESCE(qt.quarantine_attention, 0)) AS score',
  ],
  [
    joinClause(securitySubquery, 'sec'),
    joinClause(availabilitySubquery, 'avail'),
    joinClause(infradevSubquery, 'infra'),
    joinClause(deferredUxSubquery, 'dux'),
    joinClause(flakyTestsSubquery, 'ft'),
    joinClause(quarantineSubquery, 'qt'),
    joinClause(bugCountsSubquery, 'bugs'),
  ],
);

// Override the ORDER BY and add LIMIT for highest impact groups
local highestImpactSql = std.strReplace(
  std.strReplace(highestImpactQuery, 'ORDER BY name ASC', 'ORDER BY score DESC\nLIMIT 10'),
  "HAVING name IS NOT NULL AND name != ''",
  "HAVING name IS NOT NULL AND name != '' AND score > 0",
);

local scoreColumnOverride = {
  matcher: { id: 'byName', options: 'score' },
  properties: [
    { id: 'displayName', value: 'Total' },
    { id: 'custom.width', value: 80 },
    { id: 'color', value: { mode: 'continuous-GrYlRd' } },
    { id: 'custom.cellOptions', value: { type: 'color-background', mode: 'gradient' } },
  ],
};

local highestImpactTable = sectionTable(
  'Highest Impact Groups',
  highestImpactSql,
  [
    scoreColumnOverride,
    domainColumnOverride('security_past_sla',
                         'Security',
                         'View all open vulnerability issues for group::${__data.fields.name}',
                         workItemsUrl(['bug%3A%3Avulnerability'])),
    domainColumnOverride('availability_past_sla',
                         'Availability',
                         'View all open availability bugs for group::${__data.fields.name}',
                         workItemsUrl(['bug%3A%3Aavailability', 'type%3A%3Abug'])),
    domainColumnOverride('infradev_past_sla',
                         'Infradev',
                         'View all open infradev issues for group::${__data.fields.name}',
                         workItemsUrl(['infradev'])),
    domainColumnOverride('deferred_ux_attention',
                         'Deferred UX',
                         'View all open bug::ux issues for group::${__data.fields.name}',
                         workItemsUrl(['bug%3A%3Aux'])),
    domainColumnOverride('flaky_tests_count',
                         'Flaky',
                         'View flaky tests for ${__data.fields.name}',
                         dxDashUrl('flaky-tests-overview.dashboard.jsonnet', 'now-7d')),
    domainColumnOverride('quarantine_attention',
                         'Quarantine',
                         'View quarantined tests for ${__data.fields.name}',
                         dxDashUrl('quarantined-tests.dashboard.jsonnet')),
    domainColumnOverride('bugs_past_slo',
                         'Bugs Missed SLO',
                         'View missed SLO bugs for group::${__data.fields.name}',
                         bugUrl(['SLO%3A%3AMissed'])),
  ],
  { h: offendersHeight, w: tableWidth, x: 0, y: offendersY },
);

local highestImpactExpl = explanationPanel('', (|||
                                                  **Top 10 groups needing attention.**

                                                  Score = sum of all domain counts. Groups with score 0 are excluded. Click any cell to drill down.

                                                  | Column | What it counts |
                                                  |--------|---------------|
                                                  | %(sec)s | %(vulnlbl)s issues past SLA (%(s1a)s %(s3a)s %(s4a)s) |
                                                  | %(avail)s | %(availlbl)s + %(buglbl)s past SLA (%(s1b)s %(s2b)s %(s3b)s %(s4b)s) |
                                                  | %(infra)s | %(infradevlbl)s issues past SLA (%(s1c)s %(s2c)s %(s3c)s %(s4c)s) |
                                                  | %(dux)s | %(uxlbl)s missing severity/priority or %(s1s2)s |
                                                  | %(flaky)s | Test files classified as flaky in last 7 days |
                                                  | %(qt)s | Missing tracking issue or quarantined > 30d |
                                                  | %(slo)s | %(buglbl)s with %(slolbl)s label |
                                                ||| % {
                                                  sec: cn('Security'),
                                                  avail: cn('Availability'),
                                                  infra: cn('Infradev'),
                                                  slo: cn('Bugs Missed SLO'),
                                                  dux: cn('Deferred UX'),
                                                  flaky: cn('Flaky'),
                                                  qt: cn('Quarantine'),
                                                  vulnlbl: lbl('bug::vulnerability'),
                                                  availlbl: lbl('bug::availability'),
                                                  buglbl: lbl('type::bug'),
                                                  infradevlbl: lbl('infradev'),
                                                  uxlbl: lbl('bug::ux'),
                                                  slolbl: lbl('SLO::Missed'),
                                                  s1a: sev('1', 'S1/S2: 30d,'),
                                                  s3a: sev('3', 'S3: 90d,'),
                                                  s4a: sev('4', 'S4: 180d'),
                                                  s1b: sev('1', 'S1: 2d,'),
                                                  s2b: sev('2', 'S2: 7d,'),
                                                  s3b: sev('3', 'S3: 30d,'),
                                                  s4b: sev('4', 'S4: 60d'),
                                                  s1c: sev('1', 'S1: 30d,'),
                                                  s2c: sev('2', 'S2: 60d,'),
                                                  s3c: sev('3', 'S3: 90d,'),
                                                  s4c: sev('4', 'S4: 120d'),
                                                  s1s2: sev('1', 'S1') + '/' + sev('2', 'S2'),
                                                })) + { gridPos: { h: offendersHeight, w: explWidth, x: tableWidth, y: offendersY } };

// ============================================================================
// Collapsed row panel containing a table + explanation side by side
local collapsedSection(title, rowY, table, expl) = {
  type: 'row',
  title: title,
  collapsed: true,
  gridPos: { h: 1, w: 24, x: 0, y: rowY },
  panels: [
    table { gridPos: { h: tableHeight, w: tableWidth, x: 0, y: rowY + 1 } },
    expl { gridPos: { h: tableHeight, w: explWidth, x: tableWidth, y: rowY + 1 } },
  ],
};

// Row 1: Issues Past SLA
local sloTable = sectionTable(
  'Issues Past SLA',
  sloAttentionQuery,
  [
    domainColumnOverride('security_past_sla',
                         'Security',
                         'View all open vulnerability issues for group::${__data.fields.name}',
                         workItemsUrl(['bug%3A%3Avulnerability'])),
    domainColumnOverride('availability_past_sla',
                         'Availability',
                         'View all open availability bugs for group::${__data.fields.name}',
                         workItemsUrl(['bug%3A%3Aavailability', 'type%3A%3Abug'])),
    domainColumnOverride('infradev_past_sla',
                         'Infradev',
                         'View all open infradev issues for group::${__data.fields.name}',
                         workItemsUrl(['infradev'])),
    domainColumnOverride('deferred_ux_attention',
                         'Deferred UX',
                         'View all open bug::ux issues for group::${__data.fields.name}',
                         workItemsUrl(['bug%3A%3Aux'])),
  ],
  { h: tableHeight, w: tableWidth, x: 0, y: 0 },
);
local sloRow = collapsedSection('Issues Past SLA', row1Y, sloTable, sloExplanation);

// Row 2: Test Health
local testTable = sectionTable(
  'Test Health',
  testHealthQuery,
  [
    domainColumnOverride('flaky_tests_count',
                         'Flaky',
                         'View flaky tests for ${__data.fields.name}',
                         dxDashUrl('flaky-tests-overview.dashboard.jsonnet', 'now-7d')),
    domainColumnOverride('quarantine_attention',
                         'Quarantine',
                         'View quarantined tests for ${__data.fields.name}',
                         dxDashUrl('quarantined-tests.dashboard.jsonnet')),
    domainColumnOverride('test_duration_amber',
                         'Duration',
                         'View test file runtimes for ${__data.fields.name}',
                         dxDashUrl('test-file-runtime-overview.dashboard.jsonnet')),
    domainColumnOverride('coverage_risk_count',
                         'Cov. Risk',
                         'View coverage health check for ${__data.fields.name}',
                         dxDashUrl('code-coverage-actionables.dashboard.jsonnet')),
  ],
  { h: tableHeight, w: tableWidth, x: 0, y: 0 },
);
local testRow = collapsedSection('Test Health', row2Y, testTable, testHealthExplanation);

// Row 3: Bugs
local bugsTable = sectionTable(
  'Bugs',
  bugsQuery,
  [
    domainColumnOverride('bugs_all',
                         'All',
                         'View all open bugs for group::${__data.fields.name}',
                         bugUrl()),
    domainColumnOverride('bugs_past_slo',
                         'Missed SLO',
                         'View missed SLO bugs for group::${__data.fields.name}',
                         bugUrl(['SLO%3A%3AMissed'])),
    domainColumnOverride('bugs_customer',
                         'Customer',
                         'View customer bugs for group::${__data.fields.name}',
                         bugUrl(['customer'])),
    domainColumnOverride('bugs_fe_customer',
                         'FE Cust.',
                         'View frontend customer bugs for group::${__data.fields.name}',
                         bugUrl(['frontend', 'customer'])),
    domainColumnOverride('bugs_fe',
                         'FE',
                         'View frontend bugs for group::${__data.fields.name}',
                         bugUrl(['frontend'], notLabels=['customer'])),
    domainColumnOverride('bugs_be_customer',
                         'BE Cust.',
                         'View backend customer bugs for group::${__data.fields.name}',
                         bugUrl(['customer'], notLabels=['frontend'])),
    domainColumnOverride('bugs_be',
                         'BE',
                         'View backend bugs for group::${__data.fields.name}',
                         bugUrl(notLabels=['frontend', 'customer'])),
    domainColumnOverride('bugs_blocked',
                         'Blocked',
                         'View blocked bugs for group::${__data.fields.name}',
                         bugUrl(['workflow%3A%3Ablocked'])),
    domainColumnOverride('bugs_vintage',
                         'Vintage',
                         'View vintage bugs for group::${__data.fields.name}',
                         bugUrl(['vintage'])),
  ],
  { h: tableHeight, w: tableWidth, x: 0, y: 0 },
);
local bugsRow = collapsedSection('Bugs', row3Y, bugsTable, bugsExplanation);

// Row 4: Proposals & Community
local proposalsTable = sectionTable(
  'Proposals & Community',
  proposalsQuery,
  [
    domainColumnOverride('feat_customer',
                         'Cust. Features',
                         'View customer feature proposals for group::${__data.fields.name}',
                         workItemsUrl(['type%3A%3Afeature', 'customer'])),
    domainColumnOverride('feat_non_customer',
                         'Features',
                         'View feature proposals for group::${__data.fields.name}',
                         workItemsUrl(['type%3A%3Afeature'])),
    domainColumnOverride('community_untriaged',
                         'Community',
                         'View untriaged community issues for group::${__data.fields.name}',
                         workItemsUrl([])),
  ],
  { h: tableHeight, w: tableWidth, x: 0, y: 0 },
);
local proposalsRow = collapsedSection('Proposals & Community', row4Y, proposalsTable, proposalsExplanation);

// ============================================================================
// Dashboard
// ============================================================================

basic.dashboard(
  'DX Insights',
  tags=['dx-insights'],
  time_from='now-30d',
  time_to='now',
  uid='dx-insights',
)
.addTemplates([
  granularityTemplate,
])
.addPanels(
  [aboutRow] + statPanels + [
    highestImpactTable,
    highestImpactExpl,
    sloRow,
    testRow,
    bugsRow,
    proposalsRow,
  ]
)
+ {
  description: 'Central hub showing the health of all GitLab groups across triage report criteria',
  refresh: '1h',
  timepicker+: { hidden: true },
  annotations: { list: [] },
  templating+: {
    list: std.filter(
      function(t) t.name != 'PROMETHEUS_DS' && t.name != 'environment',
      super.list
    ),
  },
}
