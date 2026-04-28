local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;

// Must match gitlab-org/quality/analytics/ci-alerts.
local SPIKE_THRESHOLD_MIN_PIPELINES = 30;
local SPIKE_THRESHOLD_CONCENTRATION_PERCENT = 40;
local SPIKE_THRESHOLD_ABSOLUTE_PIPELINES = 60;
local FLAKY_MIN_FAILURE_DAYS = 3;
local FLAKY_MAX_DAYS_SINCE_LAST = 3;
local FLAKY_MIN_DISTINCT_BRANCHES = 10;
local FLAKY_MIN_MASTER_PIPELINES = 1;

local blockingPipelinesCte =
  "blocking_pipelines AS (\n  SELECT DISTINCT ci_pipeline_id, failure_date\n  FROM test_metrics.blocking_test_failures_mv btf\n  INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\n  WHERE btf.ci_project_path = '${project}'\n    AND btf.failure_date >= toDate($__fromTime)\n    AND btf.failure_date <= toDate($__toTime)\n    AND bm.allow_failure = false\n    AND bm.status = 'failed'\n)";

local pipelineFailuresFilteredCte =
  "pipeline_failures_filtered AS (\n  SELECT\n    pf.failure_date,\n    pf.ci_pipeline_id,\n    pf.failed_files\n  FROM test_metrics.blocking_failures_daily_pipeline_mv pf\n  INNER JOIN blocking_pipelines bp ON pf.ci_pipeline_id = bp.ci_pipeline_id\n    AND pf.failure_date = bp.failure_date\n  WHERE pf.ci_project_path = '${project}'\n    AND pf.failure_date >= toDate($__fromTime)\n    AND pf.failure_date <= toDate($__toTime)\n)";

local classificationCte(extra_filters='', include_group=false) =
  'file_metrics AS (\n  SELECT\n    btf.file_path,\n'
  + (if include_group then '    any(btf.`group`) as `group`,\n' else '')
  + '    COUNT(DISTINCT btf.ci_pipeline_id) as total_pipelines,\n'
  + '    COUNT(DISTINCT btf.ci_job_id) as failed_jobs,\n'
  + '    COUNT(DISTINCT btf.failure_date) as failure_days,\n'
  + "    dateDiff('day', MAX(btf.failure_date), toDate($__toTime)) as days_since_last,\n"
  + '    COUNT(DISTINCT btf.location) as test_count,\n'
  + '    COUNT(DISTINCT btf.ci_branch) as distinct_branches,\n'
  + "    countIf(DISTINCT btf.ci_pipeline_id, btf.ci_branch = 'master') as master_pipelines\n"
  + '  FROM test_metrics.blocking_test_failures_mv btf\n'
  + '  INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\n'
  + "  WHERE btf.ci_project_path = '${project}'\n"
  + '    AND btf.timestamp >= $__fromTime\n'
  + '    AND btf.timestamp <= $__toTime\n'
  + '    AND bm.allow_failure = false\n'
  + "    AND bm.status = 'failed'\n"
  + (if extra_filters != '' then '    ' + extra_filters + '\n' else '')
  + '  GROUP BY btf.file_path\n'
  + '),\nwindowed AS (\n  SELECT\n    btf.file_path,\n'
  + '    toStartOfInterval(btf.timestamp, INTERVAL 12 HOUR) as window,\n'
  + '    COUNT(DISTINCT btf.ci_pipeline_id) as pipelines_in_window\n'
  + '  FROM test_metrics.blocking_test_failures_mv btf\n'
  + '  INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\n'
  + "  WHERE btf.ci_project_path = '${project}'\n"
  + '    AND btf.timestamp >= $__fromTime\n'
  + '    AND btf.timestamp <= $__toTime\n'
  + '    AND bm.allow_failure = false\n'
  + "    AND bm.status = 'failed'\n"
  + (if extra_filters != '' then '    ' + extra_filters + '\n' else '')
  + '  GROUP BY btf.file_path, window\n'
  + '),\nclustered AS (\n  SELECT\n    file_path,\n'
  + '    MAX(pipelines_in_window) as max_in_12h\n  FROM windowed\n  GROUP BY file_path\n'
  + '),\nfile_classifications AS (\n  SELECT\n    fm.file_path,\n    CASE\n'
  + '      WHEN c.max_in_12h >= ' + std.toString(SPIKE_THRESHOLD_MIN_PIPELINES) + '\n'
  + '        AND (\n'
  + '          round(c.max_in_12h * 100.0 / fm.total_pipelines, 1) >= ' + std.toString(SPIKE_THRESHOLD_CONCENTRATION_PERCENT) + '\n'
  + '          OR c.max_in_12h >= ' + std.toString(SPIKE_THRESHOLD_ABSOLUTE_PIPELINES) + '\n'
  + "        )\n        THEN 'master_broken'\n"
  + '      WHEN fm.failure_days >= ' + std.toString(FLAKY_MIN_FAILURE_DAYS) + '\n'
  + '        AND fm.days_since_last <= ' + std.toString(FLAKY_MAX_DAYS_SINCE_LAST) + '\n'
  + '        AND fm.distinct_branches >= ' + std.toString(FLAKY_MIN_DISTINCT_BRANCHES) + '\n'
  + '        AND fm.master_pipelines >= ' + std.toString(FLAKY_MIN_MASTER_PIPELINES) + '\n'
  + "        THEN 'flaky'\n      ELSE 'unclear'\n    END as classification\n"
  + '  FROM file_metrics fm\n  INNER JOIN clustered c ON fm.file_path = c.file_path\n)';

local pipelineClassificationCte(granularity) =
  'pipeline_failures AS (\n  SELECT\n    ' + granularity + " as period,\n    ci_pipeline_id,\n    groupUniqArrayMerge(failed_files) as files\n  FROM pipeline_failures_filtered\n  GROUP BY period, ci_pipeline_id\n),\npipeline_classifications AS (\n  SELECT\n    pf.period,\n    pf.ci_pipeline_id,\n    maxIf(fc.classification, fc.classification = 'flaky') as has_flaky\n  FROM pipeline_failures pf\n  ARRAY JOIN pf.files as file\n  LEFT JOIN file_classifications fc ON fc.file_path = file\n  GROUP BY pf.period, pf.ci_pipeline_id\n)";

local withCtes(ctes) = 'WITH\n' + std.join(',\n', ctes);

local varFilters =
  'AND btf.run_type IN (${run_type:singlequote})\n    AND btf.pipeline_type IN (${pipeline_type:singlequote})';

local totalPipelinesCte(granularity) =
  local pipelineGranularity = std.strReplace(granularity, 'failure_date', 'toDate(created_at)');
  'total_pipelines_cte AS (\n'
  + '  SELECT\n'
  + '    toDateTime(' + pipelineGranularity + ') as period,\n'
  + "    countIf((is_merge_request = true AND pre_merge_check = false) OR (ref = 'master' AND source IN ('push', 'schedule'))) AS total_pipelines\n"
  + '  FROM ci_metrics.finished_pipelines_mv\n'
  + "  WHERE project_path = '${project}'\n"
  + "    AND source != 'parent_pipeline'\n"
  + '    AND created_at >= $__fromTime\n'
  + '    AND created_at < $__toTime\n'
  + '  GROUP BY period\n'
  + ')';

local flakyBlockedQuery(granularity) =
  withCtes([
    blockingPipelinesCte,
    pipelineFailuresFilteredCte,
    classificationCte(),
    pipelineClassificationCte(granularity),
  ])
  + "\nSELECT\n  toDateTime(period) as time,\n  countIf(has_flaky = 'flaky') as flaky_blocked_pipelines\nFROM pipeline_classifications\nGROUP BY period\nORDER BY period";

local totalPipelinesOnlyQuery(granularity) =
  local pipelineGranularity = std.strReplace(granularity, 'failure_date', 'toDate(created_at)');
  'SELECT\n  toDateTime(' + pipelineGranularity + ') as time,\n'
  + "  countIf((is_merge_request = true AND pre_merge_check = false) OR (ref = 'master' AND source IN ('push', 'schedule'))) AS total_pipelines\n"
  + 'FROM ci_metrics.finished_pipelines_mv\n'
  + "WHERE project_path = '${project}'\n"
  + "  AND source != 'parent_pipeline'\n"
  + '  AND created_at >= $__fromTime\n'
  + '  AND created_at < $__toTime\n'
  + 'GROUP BY time\nORDER BY time';

local flakyRateOnlyQuery(granularity) =
  withCtes([
    blockingPipelinesCte,
    pipelineFailuresFilteredCte,
    classificationCte(),
    pipelineClassificationCte(granularity),
    totalPipelinesCte(granularity),
  ])
  + "\nSELECT\n  toDateTime(pc.period) as time,\n  round(countIf(pc.has_flaky = 'flaky') * 100.0 / nullIf(any(tp.total_pipelines), 0), 2) as flaky_rate_pct\n"
  + 'FROM pipeline_classifications pc\n'
  + 'LEFT JOIN total_pipelines_cte tp ON toDate(tp.period) = toDate(pc.period)\n'
  + 'GROUP BY pc.period\n'
  + 'ORDER BY pc.period';

local absolutePanel(title, granularity, description='') =
  panels.timeSeriesPanel(
    title,
    flakyBlockedQuery(granularity),
    description=description,
  ) {
    targets+: [
      {
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: totalPipelinesOnlyQuery(granularity),
        refId: 'B',
      },
    ],
    fieldConfig+: {
      overrides+: [
        {
          matcher: { id: 'byName', options: 'total_pipelines' },
          properties: [
            { id: 'custom.axisPlacement', value: 'right' },
            { id: 'custom.axisLabel', value: 'Total Pipelines' },
            { id: 'custom.drawStyle', value: 'line' },
            { id: 'custom.lineStyle', value: { dash: [10, 10], fill: 'dash' } },
            { id: 'custom.lineWidth', value: 1 },
            { id: 'custom.fillOpacity', value: 0 },
            { id: 'color', value: { fixedColor: 'text', mode: 'fixed' } },
          ],
        },
      ],
    },
  };

local ratePanel(title, granularity, description='') =
  panels.timeSeriesPanel(
    title,
    flakyRateOnlyQuery(granularity),
    description=description,
    unit='percent',
  );

basic.dashboard(
  'Flaky Tests Overview',
  tags=['flaky-tests'] + config.testMetricsTags,
  time_from='now-30d',
  time_to='now',
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  includePrometheusDatasourceTemplate=false,
  uid='flaky-tests-overview',
)
.addTemplate(
  template.new(
    'project',
    panels.clickHouseDatasource,
    "SELECT DISTINCT ci_project_path\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY ci_project_path",
    current='gitlab-org/gitlab',
  ),
)
.addTemplate(
  template.new(
    'run_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT run_type \nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY run_type",
    includeAll=true,
  ),
)
.addTemplate(
  template.new(
    'pipeline_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT pipeline_type \nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY pipeline_type",
    includeAll=true,
  ),
)

.addPanel(
  row.new(title='Overview', collapse=false),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanel(
  {
    type: 'text',
    title: '',
    options: {
      content: '## Classification\n\n**🔴 Master-Broken** (filtered)\n\nPast incidents - filtered even if residual failures continue\n\n- ≥' + std.toString(SPIKE_THRESHOLD_MIN_PIPELINES) + ' pipelines in any 12h window\n- AND either: ≥' + std.toString(SPIKE_THRESHOLD_CONCENTRATION_PERCENT) + '% of all failures occurred in the peak 12h window OR ≥' + std.toString(SPIKE_THRESHOLD_ABSOLUTE_PIPELINES) + ' pipelines in the peak window\n\n**🟡 Flaky** (reported)\n\nPersistent, active problems needing fixes\n\n- Failures spread over ≥' + std.toString(FLAKY_MIN_FAILURE_DAYS) + ' days\n- Most recent failure within last ' + std.toString(FLAKY_MAX_DAYS_SINCE_LAST) + ' days\n- At least ' + std.toString(FLAKY_MIN_MASTER_PIPELINES) + ' master failure\n- Failed across ≥' + std.toString(FLAKY_MIN_DISTINCT_BRANCHES) + ' distinct branches (environment diversity)\n- No major spike\n\n**⚪ Unclear**\n\nDoes not meet flaky criteria: low branch diversity, no master failure, recently resolved, or insufficient data',
      mode: 'markdown',
    },
    fieldConfig: {
      defaults: {},
      overrides: [],
    },
    pluginVersion: '12.3.1',
  },
  gridPos={ x: 0, y: 1, w: 24, h: 12 },
)

.addPanel(
  ratePanel(
    'Flaky Blocked Pipeline Rate - Weekly',
    'toMonday(failure_date)',
    description='Rate of flaky-blocked pipelines as % of total MR + master pipelines (excl. merge train, incl. canceled).',
  ),
  gridPos={ x: 0, y: 13, w: 24, h: 6 },
)
.addPanel(
  absolutePanel(
    'Flaky Blocked Pipelines vs Total - Weekly',
    'toMonday(failure_date)',
    description='Flaky-blocked pipelines (left axis) vs total MR + master pipeline volume (right axis, dashed).\n\nNumerator: unique pipelines blocked by a flaky test (allow_failure=false).\nDenominator: MR pipelines (excl. merge train) + master push + master schedule. Merge train pipelines run a single job with no tests and are excluded. Canceled pipelines are included.',
  ),
  gridPos={ x: 0, y: 19, w: 24, h: 8 },
)

.addPanel(
  panels.tablePanel(
    'Classified Blocking Failures (flaky + master-broken only)',
    withCtes([
      classificationCte(extra_filters=varFilters, include_group=true),
    ])
    + '\nSELECT\n  fc.classification,\n'
    + '  fm.file_path,\n  fm.`group`,\n'
    + '  fm.total_pipelines as blocked_pipelines,\n  fm.failed_jobs,\n'
    + '  c.max_in_12h as max_blocked_pipelines_in_12h,\n'
    + '  round(c.max_in_12h * 100.0 / fm.total_pipelines, 1) as peak_12h_concentration_percent,\n'
    + '  fm.failure_days,\n  fm.days_since_last,\n  fm.test_count,\n'
    + '  fm.distinct_branches,\n  fm.master_pipelines\n'
    + 'FROM file_metrics fm\n'
    + 'INNER JOIN clustered c ON fm.file_path = c.file_path\n'
    + 'INNER JOIN file_classifications fc ON fm.file_path = fc.file_path\n'
    + "WHERE fc.classification != 'unclear'\n"
    + 'ORDER BY blocked_pipelines DESC',
    sortBy=[{ desc: true, displayName: 'blocked_pipelines' }],
    overrides=[
      {
        matcher: { id: 'byName', options: 'file_path' },
        properties: [
          { id: 'custom.width', value: 728 },
          {
            id: 'links',
            value: [
              {
                targetBlank: true,
                title: 'View details',
                url: '/d/dx-flaky-test-file-overview/dx3a-test-file-failure-overview?var-file_path=${__data.fields.file_path}&from=${__from}&to=${__to}&var-project=${project}&var-run_type=All&var-pipeline_type=All',
              },
            ],
          },
        ],
      },
      { matcher: { id: 'byName', options: 'max_blocked_pipelines_in_12h' }, properties: [{ id: 'custom.width', value: 232 }] },
      { matcher: { id: 'byName', options: 'peak_12h_concentration_percent' }, properties: [{ id: 'custom.width', value: 246 }] },
      { matcher: { id: 'byName', options: 'blocked_pipelines' }, properties: [{ id: 'custom.width', value: 164 }] },
      { matcher: { id: 'byName', options: 'failed_jobs' }, properties: [{ id: 'custom.width', value: 100 }] },
      { matcher: { id: 'byName', options: 'failure_days' }, properties: [{ id: 'custom.width', value: 106 }] },
      { matcher: { id: 'byName', options: 'days_since_last' }, properties: [{ id: 'custom.width', value: 134 }] },
      { matcher: { id: 'byName', options: 'test_count' }, properties: [{ id: 'custom.width', value: 94 }] },
      { matcher: { id: 'byName', options: 'classification' }, properties: [{ id: 'custom.width', value: 127 }] },
      { matcher: { id: 'byName', options: 'group' }, properties: [{ id: 'custom.width', value: 154 }] },
    ],
  ) + {
    description: 'Classified Blocking Failures\n\nShows only test files classified as flaky or master-broken (unclear files are excluded).\n\nClassifications:\n- master_broken: Past incidents - high concentration of failures in 12h window\n- flaky: Active problems - at least ' + std.toString(FLAKY_MIN_MASTER_PIPELINES) + ' master failure, ≥' + std.toString(FLAKY_MIN_DISTINCT_BRANCHES) + ' distinct branches, failures spread over multiple days\n\nMetrics:\n- blocked_pipelines: Unique pipelines this file blocked\n- failed_jobs: Number of jobs that failed\n- max_blocked_pipelines_in_12h: Peak failures in any 12-hour window\n- failure_days: Number of distinct days with failures\n- days_since_last: Days since most recent failure\n- test_count: Number of distinct tests in this file\n- distinct_branches: Number of unique branches where this file failed\n- master_pipelines: Number of master pipelines where this file failed\n\nUse filters to drill down by run_type/pipeline_type.',
  },
  gridPos={ x: 0, y: 27, w: 24, h: 11 },
)

.addPanel(
  row.new(title='🧪 Validate north star metric accuracy', collapse=false),
  gridPos={ x: 0, y: 32, w: 24, h: 1 },
)
.addPanel(
  panels.tablePanel(
    'North Star Validation',
    withCtes([
      blockingPipelinesCte,
      pipelineFailuresFilteredCte,
      classificationCte(),
      pipelineClassificationCte('failure_date'),
    ])
    + ",\nflaky_pipelines_by_day AS (\n  SELECT\n    period as failure_date,\n    ci_pipeline_id\n  FROM pipeline_classifications\n  WHERE has_flaky = 'flaky'\n),\nground_truth_flaky_files AS (\n  SELECT file_path\n  FROM file_classifications\n  WHERE classification = 'flaky'\n),\nblocking_pipelines_list AS (\n  SELECT DISTINCT ci_pipeline_id\n  FROM blocking_pipelines\n),\nground_truth_daily AS (\n  SELECT\n    btf.failure_date,\n    COUNT(DISTINCT btf.ci_pipeline_id) as pipelines\n  FROM test_metrics.blocking_test_failures_mv btf\n  INNER JOIN ground_truth_flaky_files gf ON btf.file_path = gf.file_path\n  WHERE btf.ci_project_path = '${project}'\n    AND btf.timestamp >= $__fromTime\n    AND btf.timestamp <= $__toTime\n    AND btf.ci_pipeline_id IN (SELECT ci_pipeline_id FROM blocking_pipelines_list)\n  GROUP BY btf.failure_date\n),\nsummary AS (\n  SELECT\n    toUInt64(count(*)) as sum_of_daily,\n    toUInt64(uniq(ci_pipeline_id)) as unique_pipelines,\n    toUInt64(count(*) - uniq(ci_pipeline_id)) as duplicates,\n    (SELECT toUInt64(sum(pipelines)) FROM ground_truth_daily) as ground_truth\n  FROM flaky_pipelines_by_day\n),\nby_day AS (\n  SELECT\n    failure_date,\n    toUInt64(count(*)) as daily_count\n  FROM flaky_pipelines_by_day\n  GROUP BY failure_date\n)\nSELECT\n  1 as sort_group,\n  toString(failure_date) as date,\n  daily_count as blocked_pipelines\nFROM by_day\n\nUNION ALL\n\nSELECT\n  2 as sort_group,\n  '' as date,\n  toUInt64(0) as blocked_pipelines\n\nUNION ALL\n\nSELECT\n  3 as sort_group,\n  'Sum (North Star with MV)' as date,\n  sum_of_daily as blocked_pipelines\nFROM summary\n\nUNION ALL\n\nSELECT\n  4 as sort_group,\n  'Unique Pipelines (North Star)' as date,\n  unique_pipelines as blocked_pipelines\nFROM summary\n\nUNION ALL\n\nSELECT\n  5 as sort_group,\n  'Multi-Day Occurrences' as date,\n  duplicates as blocked_pipelines\nFROM summary\n\nUNION ALL\n\nSELECT\n  6 as sort_group,\n  'Sum (Ground Truth without MV)' as date,\n  ground_truth as blocked_pipelines\nFROM summary\n\nORDER BY sort_group, date DESC",
    overrides=[
      {
        matcher: { id: 'byName', options: 'sort_group' },
        properties: [{ id: 'custom.hideFrom.viz', value: true }],
      },
    ],
  ),
  gridPos={ x: 0, y: 33, w: 24, h: 19 },
)

.addPanel(
  row.new(title='(Drilldown) Differences between failed tests dashboard and this dashboard 🧪🥼', collapse=false),
  gridPos={ x: 0, y: 52, w: 24, h: 1 },
)
.addPanel(
  {
    type: 'text',
    title: '',
    options: {
      content: "## Table 1: Failed Retry Rate\nShows test files by failed retry rate from `test_results_spec_file_hourly_failure_counts_mv`.\n\n**Problem:** \n- Assumes `test_retried = true` means CI job failed (correct)\n- BUT misses tests that failed without retry (CI job failed early, no retry attempted)\n- Doesn't filter by `allow_failure`, so includes non-blocking CI jobs\n\n## Table 2: Blocking Failures Only\nShows failures from `blocking_test_failures_mv` joined with `build_metrics`.\n\n**Fix:** \n- Explicitly checks CI job status (`bm.status = 'failed'`)\n- Filters to blocking CI jobs only (`bm.allow_failure = false`)\n- Accurate view of tests that actually blocked pipelines",
      mode: 'markdown',
    },
    fieldConfig: {
      defaults: {},
      overrides: [],
    },
    pluginVersion: '12.3.1',
  },
  gridPos={ x: 0, y: 53, w: 24, h: 12 },
)
.addPanel(
  panels.tablePanel(
    'Failed Retry Rate',
    "SELECT \n  file_path,\n  group,\n  uniqIfMerge(failed_jobs) as jobs_with_failed_retried_tests,\n  uniqMerge(total_jobs) as total_jobs_executed,\n  round((jobs_with_failed_retried_tests / total_jobs_executed) * 100, 2) as failed_retry_rate_percent\nFROM test_metrics.test_results_spec_file_hourly_failure_counts_mv\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY file_path, group\nHAVING jobs_with_failed_retried_tests > 0\nORDER BY jobs_with_failed_retried_tests DESC\nLIMIT 50",
    sortBy=[{ desc: true, displayName: 'jobs_with_failed_retried_tests' }],
    overrides=[
      { matcher: { id: 'byName', options: 'file_path' }, properties: [{ id: 'custom.width', value: 721 }] },
      { matcher: { id: 'byName', options: 'jobs_with_failed_retried_tests' }, properties: [{ id: 'custom.width', value: 252 }] },
      { matcher: { id: 'byName', options: 'total_jobs_executed' }, properties: [{ id: 'custom.width', value: 173 }] },
      { matcher: { id: 'byName', options: 'failed_retry_rate_percent' }, properties: [{ id: 'custom.width', value: 199 }] },
    ],
  ),
  gridPos={ x: 0, y: 65, w: 24, h: 11 },
)
.addPanel(
  panels.tablePanel(
    'Failures by Blocking Status',
    "SELECT \n  btf.file_path,\n  any(btf.`group`) as group,\n  COUNT(DISTINCT CASE WHEN bm.allow_failure = false THEN btf.ci_pipeline_id END) as blocked_pipelines,\n  COUNT(DISTINCT btf.ci_job_id) as total_failed_jobs,\n  COUNT(DISTINCT CASE WHEN bm.allow_failure = false THEN btf.ci_job_id END) as blocking_jobs,\n  COUNT(DISTINCT CASE WHEN bm.allow_failure = true THEN btf.ci_job_id END) as allowed_to_fail_jobs,\n  COUNT(DISTINCT btf.location) as test_count\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.run_type IN (${run_type:singlequote})\n  AND btf.pipeline_type IN (${pipeline_type:singlequote})\n  AND btf.timestamp >= $__fromTime\n  AND btf.timestamp <= $__toTime\n  AND bm.status = 'failed'\nGROUP BY btf.file_path\nORDER BY blocked_pipelines DESC\nLIMIT 50",
    sortBy=[{ desc: true, displayName: 'blocked_pipelines' }],
    overrides=[
      {
        matcher: { id: 'byName', options: 'file_path' },
        properties: [
          { id: 'custom.width', value: 721 },
          {
            id: 'links',
            value: [
              {
                targetBlank: true,
                title: 'View details',
                url: '/d/dx-flaky-test-file-overview/dx3a-test-file-failure-overview?var-file_path=${__data.fields.file_path}&from=${__from}&to=${__to}&var-project=${project}&var-run_type=All&var-pipeline_type=All',
              },
            ],
          },
        ],
      },
      { matcher: { id: 'byName', options: 'blocked_pipelines' }, properties: [{ id: 'custom.width', value: 185 }] },
      { matcher: { id: 'byName', options: 'total_failed_jobs' }, properties: [{ id: 'custom.width', value: 163 }] },
      { matcher: { id: 'byName', options: 'blocking_jobs' }, properties: [{ id: 'custom.width', value: 155 }] },
      { matcher: { id: 'byName', options: 'allowed_to_fail_jobs' }, properties: [{ id: 'custom.width', value: 166 }] },
      { matcher: { id: 'byName', options: 'test_count' }, properties: [{ id: 'custom.width', value: 100 }] },
    ],
  ),
  gridPos={ x: 0, y: 76, w: 24, h: 11 },
)
+ { timezone: 'browser' }
