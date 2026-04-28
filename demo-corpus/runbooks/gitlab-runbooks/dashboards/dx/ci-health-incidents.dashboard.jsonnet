local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local template = grafana.template;

local ciHealthIncidentsProject = 'gitlab-org/quality/analytics/ci-health-incidents';
local ciHealthWatchProject = 'gitlab-org/quality/analytics/ci-health-watch';

local incidentTableFieldConfig = {
  defaults: {
    color: { mode: 'thresholds' },
    custom: {
      align: 'auto',
      cellOptions: { type: 'auto' },
      footer: { reducers: [] },
      inspect: false,
    },
    mappings: [],
    thresholds: {
      mode: 'absolute',
      steps: [
        { color: 'green', value: 0 },
        { color: 'red', value: 80 },
      ],
    },
  },
  overrides: [
    {
      matcher: { id: 'byName', options: 'web_url' },
      properties: [{ id: 'custom.hidden', value: true }],
    },
    {
      matcher: { id: 'byName', options: 'drill_down_url' },
      properties: [{ id: 'custom.hidden', value: true }],
    },
    {
      matcher: { id: 'byName', options: 'stats' },
      properties: [
        { id: 'custom.width', value: 300 },
        { id: 'custom.cellOptions', value: { type: 'color-text' } },
        {
          id: 'links',
          value: [
            {
              targetBlank: true,
              title: '${__value.text}',
              url: '${__data.fields.drill_down_url}',
            },
          ],
        },
      ],
    },
    {
      matcher: { id: 'byName', options: 'incident' },
      properties: [
        { id: 'custom.width', value: 500 },
        {
          id: 'links',
          value: [
            {
              targetBlank: true,
              title: 'View incident',
              url: '${__data.fields.web_url}',
            },
          ],
        },
      ],
    },
    {
      matcher: { id: 'byName', options: 'age_hours' },
      properties: [
        { id: 'displayName', value: 'age (h)' },
        { id: 'custom.width', value: 80 },
      ],
    },
    {
      matcher: { id: 'byName', options: 'blocked_pipelines' },
      properties: [{ id: 'custom.width', value: 140 }],
    },
    {
      matcher: { id: 'byName', options: 'impacted_mrs' },
      properties: [{ id: 'custom.width', value: 110 }],
    },
    {
      matcher: { id: 'byName', options: 'status' },
      properties: [{ id: 'custom.width', value: 110 }],
    },
    {
      matcher: { id: 'byName', options: 'cause' },
      properties: [{ id: 'custom.width', value: 160 }],
    },
    {
      matcher: { id: 'byName', options: 'why_green' },
      properties: [
        { id: 'displayName', value: 'why green' },
        { id: 'custom.width', value: 130 },
      ],
    },
  ],
};

local incidentTableOptions = {
  cellHeight: 'sm',
  showHeader: true,
  sortBy: [{ desc: true, displayName: 'age (h)' }],
};

local incidentQuery(project) =
  'WITH issues AS (\n' +
  '  SELECT\n' +
  '    title,\n' +
  '    web_url,\n' +
  '    created_at,\n' +
  '    closed_at,\n' +
  '    state,\n' +
  '    labels,\n' +
  "    extract(title, '- `(.+?)` ') AS extracted_stat\n" +
  '  FROM work_item_metrics.issue_metrics\n' +
  "  WHERE project_path = '" + project + "'\n" +
  '    AND (web_url, updated_at) IN (\n' +
  '      SELECT web_url, max(updated_at)\n' +
  '      FROM work_item_metrics.issue_metrics\n' +
  "      WHERE project_path = '" + project + "'\n" +
  '      GROUP BY web_url\n' +
  '    )\n' +
  ')\n' +
  'SELECT\n' +
  "  substring(i.title, position(i.title, ' - ') + 3) AS incident,\n" +
  '  i.extracted_stat AS stats,\n' +
  '  if(\n' +
  "    i.extracted_stat LIKE '%_spec%' OR i.extracted_stat LIKE '%.rb',\n" +
  "    concat('/d/dx-single-test-overview?var-file_path=', i.extracted_stat),\n" +
  "    concat('/d/dx-failure-analysis?var-failure_category_var=', i.extracted_stat)\n" +
  '  ) AS drill_down_url,\n' +
  '  i.web_url,\n' +
  "  dateDiff('hour', i.created_at, now()) AS age_hours,\n" +
  "  replaceRegexpOne(arrayFirst(x -> x LIKE 'ci-alerts::%', i.labels), '^ci-alerts::', '') AS status,\n" +
  "  replaceRegexpOne(arrayFirst(x -> x LIKE 'ci-health-cause::%', i.labels), '^ci-health-cause::', '') AS cause,\n" +
  "  replaceRegexpOne(arrayFirst(x -> x LIKE 'ci-health-why-green-in-mrs::%', i.labels), '^ci-health-why-green-in-mrs::', '') AS why_green,\n" +
  '  coalesce(fc.blocked_pipelines, btf.blocked_pipelines, 0) AS blocked_pipelines,\n' +
  '  coalesce(fc.impacted_mrs, btf.impacted_mrs, 0) AS impacted_mrs\n' +
  'FROM issues i\n' +
  'LEFT JOIN (\n' +
  '  SELECT fa.failure_category,\n' +
  '    countDistinct(bm.pipeline_id) AS blocked_pipelines,\n' +
  "    countDistinctIf(bm.ref, bm.ref != 'master') AS impacted_mrs\n" +
  '  FROM ci_metrics.failure_analysis_metrics fa\n' +
  '  JOIN ci_metrics.build_metrics bm ON fa.job_id = bm.id\n' +
  "  WHERE fa.project_path IN ('gitlab-org/gitlab', 'gitlab-org/gitlab-foss')\n" +
  '    AND $__timeFilter(fa.created_at)\n' +
  "    AND bm.status = 'failed' AND NOT bm.allow_failure\n" +
  '  GROUP BY fa.failure_category\n' +
  ') fc ON fc.failure_category = i.extracted_stat\n' +
  'LEFT JOIN (\n' +
  '  SELECT btf.file_path,\n' +
  '    countDistinct(btf.ci_pipeline_id) AS blocked_pipelines,\n' +
  "    countDistinctIf(btf.ci_branch, btf.ci_branch != 'master') AS impacted_mrs\n" +
  '  FROM test_metrics.blocking_test_failures_mv btf\n' +
  '  JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\n' +
  "  WHERE btf.ci_project_path IN ('gitlab-org/gitlab', 'gitlab-org/gitlab-foss')\n" +
  '    AND $__timeFilter(btf.timestamp)\n' +
  "    AND bm.status = 'failed' AND NOT bm.allow_failure\n" +
  '  GROUP BY btf.file_path\n' +
  ') btf ON btf.file_path = i.extracted_stat\n' +
  'WHERE (\n' +
  "  ('${incident_state}' = 'open' AND i.state = 'opened')\n" +
  "  OR ('${incident_state}' = 'closed' AND i.state = 'closed' AND $__timeFilter(i.closed_at))\n" +
  "  OR ('${incident_state}' = 'All' AND (i.state = 'opened' OR $__timeFilter(i.closed_at)))\n" +
  ')\n' +
  'ORDER BY age_hours DESC\n';

(basic.dashboard(
   title='CI Health Incidents',
   description='CI health monitoring combining active incident tracking with raw baseline signal. Use the top rows for operational triage (what incidents are open?), and the bottom rows to validate that the detection system matches the raw data.',
   tags=['ci-health', 'ci-metrics'],
   time_from='now-12h',
   time_to='now',
   includeEnvironmentTemplate=false,
   includeStandardEnvironmentAnnotations=false,
   includePrometheusDatasourceTemplate=false,
 ) + {
   timezone: 'browser',
   refresh: '5m',
 })
.addTemplate(
  template.new(
    'project',
    panels.clickHouseDatasource,
    |||
      SELECT DISTINCT ci_project_path
      FROM test_metrics.blocking_test_failures_mv
      WHERE timestamp >= toDateTime($__from / 1000)
        AND timestamp <= toDateTime($__to / 1000)
      ORDER BY ci_project_path
    |||,
    current='gitlab-org/gitlab',
    includeAll=false,
    multi=true,
    refresh='time',
    label='Project',
  ),
)
.addTemplate(
  template.custom(
    'incident_state',
    'open,closed',
    'open',
    label='Incident state',
    includeAll=true,
    allValues='All',
  ),
)
.addPanel(
  grafana.row.new(title='Active CI Health Incidents', collapse=false),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanel(
  {
    type: 'table',
    title: 'CI Health Incidents',
    datasource: panels.clickHouseDatasource,
    description: 'Open CI health incidents from the ci-health-incidents project. Sorted by age (oldest first). Click "incident" to open the GitLab issue, click "drill down" to open the relevant Grafana dashboard for that test file or failure category.',
    fieldConfig: incidentTableFieldConfig,
    options: incidentTableOptions,
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 1,
        pluginVersion: '4.14.0',
        queryType: 'table',
        rawSql: incidentQuery(ciHealthIncidentsProject),
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 1, w: 24, h: 10 },
)
.addPanel(
  {
    type: 'table',
    title: 'CI Health Watch (Infrastructure)',
    datasource: panels.clickHouseDatasource,
    description: 'Infrastructure-level problems tracked in ci-health-watch. Lower urgency than active incidents — these require longer investigations.',
    fieldConfig: incidentTableFieldConfig,
    options: incidentTableOptions,
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 1,
        pluginVersion: '4.14.0',
        queryType: 'table',
        rawSql: incidentQuery(ciHealthWatchProject),
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 11, w: 24, h: 6 },
)
.addPanel(
  grafana.row.new(title='Baseline Signal — Tests (Independent Ground Truth)', collapse=false),
  gridPos={ x: 0, y: 17, w: 24, h: 1 },
)
.addPanel(
  {
    type: 'table',
    title: 'Tests Requiring Action',
    datasource: panels.clickHouseDatasource,
    description: 'Tests that failed in jobs that ultimately failed, sorted by impact. Independent of the incident system — use this to cross-check that open incidents above match what the raw data shows. If a test is hot here but has no incident above, there may be a detection gap.',
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        custom: {
          align: 'auto',
          cellOptions: { type: 'auto' },
          footer: { reducers: [] },
          inspect: false,
        },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
            { color: 'red', value: 80 },
          ],
        },
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'file_link' },
          properties: [{ id: 'custom.hidden', value: true }],
        },
        {
          matcher: { id: 'byName', options: 'test' },
          properties: [
            { id: 'custom.width', value: 573 },
            {
              id: 'links',
              value: [
                {
                  targetBlank: true,
                  title: '${__value.text}',
                  url: 'd/dx-flaky-test-file-overview/dx3a-flaky-test-file-failure-overview/?from=${__from}&to=${__to}&var-project=${project:raw}&var-file_path=${__data.fields.test}',
                },
              ],
            },
          ],
        },
        {
          matcher: { id: 'byName', options: 'responsible_group' },
          properties: [{ id: 'custom.width', value: 185 }],
        },
        {
          matcher: { id: 'byName', options: 'blocked_pipelines' },
          properties: [{ id: 'custom.width', value: 158 }],
        },
        {
          matcher: { id: 'byName', options: 'impacted_mrs' },
          properties: [{ id: 'custom.width', value: 120 }],
        },
        {
          matcher: { id: 'byName', options: 'master_pipelines' },
          properties: [{ id: 'custom.width', value: 140 }],
        },
        {
          matcher: { id: 'byName', options: 'mr_pipelines' },
          properties: [{ id: 'custom.width', value: 110 }],
        },
      ],
    },
    options: {
      cellHeight: 'sm',
      showHeader: true,
      sortBy: [{ desc: true, displayName: 'blocked_pipelines' }],
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 1,
        pluginVersion: '4.14.0',
        queryType: 'table',
        rawSql: |||
          SELECT
            btf.file_path as test,
            any(concat(
              'https://gitlab.com/gitlab-org/gitlab/-/blob/master/',
              if(btf.file_path LIKE 'qa/specs/%', concat('qa/', btf.file_path), btf.file_path)
            )) as file_link,
            any(btf.group) as responsible_group,
            countDistinct(btf.ci_pipeline_id) as blocked_pipelines,
            countDistinctIf(btf.ci_branch,
              btf.ci_branch != 'master' AND btf.pipeline_type NOT LIKE 'default_branch%'
            ) as impacted_mrs,
            countDistinctIf(btf.ci_pipeline_id,
              btf.ci_branch = 'master' OR btf.pipeline_type LIKE 'default_branch%'
            ) as master_pipelines,
            countDistinctIf(btf.ci_pipeline_id,
              btf.ci_branch != 'master' AND btf.pipeline_type NOT LIKE 'default_branch%'
            ) as mr_pipelines,
            countDistinct(btf.location) as failing_tests
          FROM test_metrics.blocking_test_failures_mv btf
          INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id
          WHERE $__timeFilter(btf.timestamp)
            AND btf.ci_project_path IN (${project:singlequote})
            AND bm.status = 'failed' AND NOT bm.allow_failure
          GROUP BY btf.file_path
          HAVING blocked_pipelines >= 3
          ORDER BY blocked_pipelines DESC
          LIMIT 20
        |||,
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 18, w: 24, h: 8 },
)
.addPanel(
  {
    type: 'timeseries',
    title: 'Top Tests Failing Over Time',
    datasource: panels.clickHouseDatasource,
    description: 'Top 20 test files by blocked pipelines. Use this to see whether a failing test is getting better or worse over the selected time window.',
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisCenteredZero: false,
          axisColorMode: 'text',
          axisLabel: '',
          axisPlacement: 'auto',
          barAlignment: 0,
          barWidthFactor: 0.6,
          drawStyle: 'line',
          fillOpacity: 0,
          gradientMode: 'none',
          hideFrom: { legend: false, tooltip: false, viz: false },
          insertNulls: false,
          lineInterpolation: 'linear',
          lineWidth: 1,
          pointSize: 5,
          scaleDistribution: { type: 'linear' },
          showPoints: 'auto',
          showValues: false,
          spanNulls: false,
          stacking: { group: 'A', mode: 'none' },
          thresholdsStyle: { mode: 'off' },
        },
        displayName: '${__field.labels.test}',
        fieldMinMax: false,
        mappings: [],
        min: 0,
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
            { color: 'red', value: 80 },
          ],
        },
      },
      overrides: [],
    },
    options: {
      legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
    },
    pluginVersion: '12.3.1',
    transformations: [{ id: 'prepareTimeSeries', options: { format: 'multi' } }],
    targets: [
      {
        editorType: 'sql',
        format: 1,
        pluginVersion: '4.14.0',
        queryType: 'table',
        rawSql: |||
          WITH top_tests AS (
            SELECT btf.file_path
            FROM test_metrics.blocking_test_failures_mv btf
            INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id
            WHERE $__timeFilter(btf.timestamp)
              AND btf.ci_project_path IN (${project:singlequote})
              AND bm.status = 'failed' AND NOT bm.allow_failure
            GROUP BY btf.file_path
            ORDER BY countDistinct(btf.ci_pipeline_id) DESC
            LIMIT 20
          )
          SELECT
            toStartOfHour(btf.timestamp) as time,
            btf.file_path as test,
            countDistinct(btf.ci_pipeline_id) as blocked_pipelines
          FROM test_metrics.blocking_test_failures_mv btf
          INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id
          WHERE $__timeFilter(btf.timestamp)
            AND btf.ci_project_path IN (${project:singlequote})
            AND bm.status = 'failed' AND NOT bm.allow_failure
            AND btf.file_path IN (SELECT file_path FROM top_tests)
          GROUP BY time, test
          ORDER BY time, test
        |||,
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 26, w: 24, h: 8 },
)
.addPanel(
  grafana.row.new(title='Baseline Signal — Jobs (Independent Ground Truth)', collapse=false),
  gridPos={ x: 0, y: 34, w: 24, h: 1 },
)
.addPanel(
  {
    type: 'table',
    title: 'Jobs Requiring Action',
    datasource: panels.clickHouseDatasource,
    description: 'Jobs failing most in the selected time range. Independent of failure categories — use this to cross-check that the failure-category system is capturing these jobs. If a job is hot here but has no incident above, the Observer failure signatures may need updating.',
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        custom: {
          align: 'auto',
          cellOptions: { type: 'auto' },
          footer: { reducers: [] },
          inspect: false,
        },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
            { color: 'red', value: 80 },
          ],
        },
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'job_name' },
          properties: [
            { id: 'custom.width', value: 348 },
            {
              id: 'links',
              value: [
                {
                  targetBlank: true,
                  title: 'Failure Analysis',
                  url: '/d/dx-failure-analysis?var-failure_category_var=${__data.fields.failure_reason}&from=${__from}&to=${__to}',
                },
              ],
            },
          ],
        },
        {
          matcher: { id: 'byName', options: 'failure_reason' },
          properties: [{ id: 'custom.width', value: 161 }],
        },
        {
          matcher: { id: 'byName', options: 'blocked_pipelines' },
          properties: [{ id: 'custom.width', value: 158 }],
        },
        {
          matcher: { id: 'byName', options: 'impacted_mrs' },
          properties: [{ id: 'custom.width', value: 120 }],
        },
        {
          matcher: { id: 'byName', options: 'master_pipelines' },
          properties: [{ id: 'custom.width', value: 140 }],
        },
        {
          matcher: { id: 'byName', options: 'mr_pipelines' },
          properties: [{ id: 'custom.width', value: 110 }],
        },
      ],
    },
    options: {
      cellHeight: 'sm',
      showHeader: true,
      sortBy: [{ desc: true, displayName: 'blocked_pipelines' }],
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 1,
        pluginVersion: '4.14.0',
        queryType: 'table',
        rawSql: |||
          SELECT
            b.name as job_name,
            b.failure_reason,
            countDistinct(b.pipeline_id) as blocked_pipelines,
            countDistinctIf(b.ref, b.ref != 'master') as impacted_mrs,
            countDistinctIf(b.pipeline_id, b.ref = 'master') as master_pipelines,
            countDistinctIf(b.pipeline_id, b.ref != 'master') as mr_pipelines
          FROM ci_metrics.build_metrics b
          WHERE $__timeFilter(b.created_at)
            AND b.project_path IN (${project:singlequote})
            AND b.status = 'failed' AND NOT b.allow_failure
          GROUP BY b.name, b.failure_reason
          HAVING blocked_pipelines >= 3
          ORDER BY blocked_pipelines DESC
          LIMIT 20
        |||,
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 35, w: 24, h: 8 },
)
.addPanel(
  {
    type: 'timeseries',
    title: 'Top Jobs Failing Over Time',
    datasource: panels.clickHouseDatasource,
    description: 'Top 10 jobs by blocked pipelines over the selected time window.',
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisCenteredZero: false,
          axisColorMode: 'text',
          axisLabel: '',
          axisPlacement: 'auto',
          barAlignment: 0,
          barWidthFactor: 0.6,
          drawStyle: 'line',
          fillOpacity: 0,
          gradientMode: 'none',
          hideFrom: { legend: false, tooltip: false, viz: false },
          insertNulls: false,
          lineInterpolation: 'linear',
          lineWidth: 1,
          pointSize: 5,
          scaleDistribution: { type: 'linear' },
          showPoints: 'auto',
          showValues: false,
          spanNulls: false,
          stacking: { group: 'A', mode: 'none' },
          thresholdsStyle: { mode: 'off' },
        },
        displayName: '${__field.labels.metric}',
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
            { color: 'red', value: 80 },
          ],
        },
      },
      overrides: [],
    },
    options: {
      legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
    },
    pluginVersion: '12.3.1',
    transformations: [{ id: 'prepareTimeSeries', options: { format: 'multi' } }],
    targets: [
      {
        editorType: 'sql',
        format: 1,
        pluginVersion: '4.14.0',
        queryType: 'table',
        rawSql: |||
          WITH top_jobs AS (
            SELECT b.name, b.failure_reason
            FROM ci_metrics.build_metrics b
            WHERE $__timeFilter(b.created_at)
              AND b.project_path IN (${project:singlequote})
              AND b.status = 'failed' AND NOT b.allow_failure
            GROUP BY b.name, b.failure_reason
            ORDER BY countDistinct(b.pipeline_id) DESC
            LIMIT 10
          )
          SELECT
            toStartOfHour(b.created_at) as time,
            concat(b.name, ' (', b.failure_reason, ')') as job,
            countDistinct(b.pipeline_id) as blocked_pipelines
          FROM ci_metrics.build_metrics b
          WHERE $__timeFilter(b.created_at)
            AND b.project_path IN (${project:singlequote})
            AND b.status = 'failed' AND NOT b.allow_failure
            AND (b.name, b.failure_reason) IN (SELECT name, failure_reason FROM top_jobs)
          GROUP BY time, job
          ORDER BY time, job
        |||,
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 43, w: 24, h: 8 },
)
