local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;


local clickhouseDatasource = panels.clickHouseDatasource;

local textPanel(content) = {
  fieldConfig: { defaults: {}, overrides: [] },
  options: {
    code: {
      language: 'plaintext',
      showLineNumbers: false,
      showMiniMap: false,
    },
    content: content,
    mode: 'markdown',
  },
  pluginVersion: '12.3.1',
  title: '',
  type: 'text',
};

// Using a COMMON clause to be used in most panel queries
local commonWhereClause =
  "WHERE ci_project_path = '${project}'"
  + '\n    AND run_type IN (${run_type:singlequote})'
  + '\n    AND group IN (${group:singlequote})'
  + '\n    AND pipeline_type IN (${pipeline_type:singlequote})'
  + '\n    AND timestamp >= $__fromTime'
  + '\n    AND timestamp <= $__toTime';

// The test suite summary is reused in multiple panels
local testSuiteSummarySql =
  'SELECT\n  $__timeInterval(timestamp) as time,\n  avg(pipeline_total) as total,\n  avg(pipeline_executed) as executed,\n  avg(pipeline_passed) as passed,\n  avg(pipeline_failed) as failed,\n  avg(pipeline_pending) as pending,\n  avg(pipeline_retried) as retried\nFROM (\n  SELECT\n    timestamp,\n    ci_pipeline_id,\n    sum(total) as pipeline_total,\n    sum(executed) as pipeline_executed,\n    sum(passed) as pipeline_passed,\n    sum(failed) as pipeline_failed,\n    sum(pending) as pipeline_pending,\n    sum(retried) as pipeline_retried\n  FROM test_metrics.test_results_hourly_overview_mv\n  ' + commonWhereClause + '\n  GROUP BY timestamp, ci_pipeline_id\n)\nGROUP BY time\nORDER BY time';

(basic.dashboard(
   title='Test Suite Overview',
   tags=config.testMetricsTags,
   uid='dx-test-suite-overview',
   time_from='now-30d',
   time_to='now',
   includeEnvironmentTemplate=false,
   includeStandardEnvironmentAnnotations=false,
   includePrometheusDatasourceTemplate=false,
 ) + {
   timezone: 'browser',
   refresh: '15m',
 })
.addTemplate(
  template.new(
    'project',
    panels.clickHouseDatasource,
    "SELECT DISTINCT ci_project_path\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE timestamp >= $__fromTime\n  AND timestamp <= $__toTime\n  AND pipeline_type = 'default_branch_pipeline'\nORDER BY ci_project_path",
    refresh='load',
    current={ text: 'gitlab-org/gitlab', value: 'gitlab-org/gitlab' },
  ),
)
.addTemplate(
  template.new(
    'run_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT run_type\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE ci_project_path = '${project}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nORDER BY run_type",
    refresh='load',
    includeAll=true,
    current={ text: 'backend-rspec-tests', value: 'backend-rspec-tests' },
  ),
)
.addTemplate(
  template.new(
    'pipeline_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT pipeline_type\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\n  AND pipeline_type != 'any'\n  AND pipeline_type != 'unknown'\nORDER BY run_type",
    refresh='load',
    includeAll=true,
    current={ text: 'default_branch_scheduled_pipeline', value: 'default_branch_scheduled_pipeline' },
  ),
)
.addTemplate(
  template.new(
    'group',
    panels.clickHouseDatasource,
    "SELECT DISTINCT group\nFROM test_metrics.test_results_hourly_ownership_data_mv\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nORDER BY group",
    refresh='load',
    includeAll=true,
    current={ text: 'All', value: '$__all' },
  ),
)
.addPanel(
  {
    type: 'stat',
    title: 'test suite summary',
    datasource: clickhouseDatasource,
    description: 'Average amount of executed tests in a single pipeline (includes running same test cases with different environment configurations)',
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
          ],
        },
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'total' },
          properties: [
            { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: '#6c726b', value: 0 }] } },
          ],
        },
        {
          matcher: { id: 'byName', options: 'executed' },
          properties: [
            { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'blue', value: 0 }] } },
          ],
        },
        {
          matcher: { id: 'byName', options: 'failed' },
          properties: [
            { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 0.0001 }] } },
          ],
        },
        {
          matcher: { id: 'byName', options: 'pending' },
          properties: [
            { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'dark-yellow', value: 0 }] } },
          ],
        },
        {
          matcher: { id: 'byName', options: 'retried' },
          properties: [
            { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'dark-orange', value: 0 }] } },
          ],
        },
      ],
    },
    options: {
      colorMode: 'value',
      graphMode: 'none',
      justifyMode: 'center',
      orientation: 'auto',
      percentChangeColorMode: 'standard',
      reduceOptions: { calcs: ['mean'], fields: '', values: false },
      showPercentChange: false,
      textMode: 'auto',
      wideLayout: true,
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        datasource: clickhouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: testSuiteSummarySql,
        refId: 'A',
      },
    ],
  },
  gridPos={ h: 8, w: 12, x: 0, y: 0 },
)
.addPanel(
  {
    type: 'stat',
    title: 'test case data',
    datasource: clickhouseDatasource,
    description: 'Maximum amount of uniq test cases executed in a single pipeline for a given day (excludes running same test cases with different environment configurations)',
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
          ],
        },
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'tests' },
          properties: [
            { id: 'color', value: { fixedColor: 'green', mode: 'fixed' } },
          ],
        },
        {
          matcher: { id: 'byName', options: 'quarantined' },
          properties: [
            { id: 'color', value: { fixedColor: 'yellow', mode: 'fixed' } },
          ],
        },
      ],
    },
    options: {
      colorMode: 'value',
      graphMode: 'none',
      justifyMode: 'auto',
      orientation: 'auto',
      percentChangeColorMode: 'inverted',
      reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
      showPercentChange: true,
      textMode: 'auto',
      wideLayout: true,
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        datasource: clickhouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: 'SELECT\n  time,\n  max(tests) as test_cases\nFROM (\n  SELECT\n    toStartOfDay(timestamp) as time,\n    ci_pipeline_id,\n    sum(uniq_tests) as tests\n  FROM test_metrics.test_results_pipeline_uniq_test_counts FINAL\n  ' + commonWhereClause + '\n  GROUP BY time, ci_pipeline_id\n)\nGROUP BY time\nORDER BY time',
        refId: 'A',
      },
    ],
  },
  gridPos={ h: 8, w: 7, x: 12, y: 0 },
)
.addPanel(
  {
    type: 'gauge',
    title: 'failed test percentage',
    datasource: clickhouseDatasource,
    description: 'Average percentage of failed tests within a test suite',
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
            { color: 'red', value: 0.00001 },
          ],
        },
        unit: 'percentunit',
      },
      overrides: [],
    },
    options: {
      minVizHeight: 75,
      minVizWidth: 75,
      orientation: 'auto',
      reduceOptions: { calcs: ['mean'], fields: '', values: false },
      showThresholdLabels: false,
      showThresholdMarkers: false,
      sizing: 'auto',
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        datasource: clickhouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: testSuiteSummarySql,
        refId: 'A',
      },
    ],
    transformations: [
      {
        id: 'calculateField',
        options: {
          alias: 'failure rate',
          binary: {
            left: { matcher: { id: 'byName', options: 'failed' } },
            operator: '/',
            right: { matcher: { id: 'byName', options: 'executed' } },
          },
          mode: 'binary',
          reduce: { reducer: 'sum' },
        },
      },
      {
        id: 'filterFieldsByName',
        options: {
          include: { names: ['failure rate'] },
        },
      },
    ],
  },
  gridPos={ h: 8, w: 5, x: 19, y: 0 },
)
.addPanel(
  panels.tablePanel(
    title='pipelines with failed tests',
    rawSql="SELECT\n  max(timestamp) as time,\n  run_type,\n  ci_pipeline_id,\n  concat(ci_server_url, '/', ci_project_path, '/-/pipelines/', toString(ci_pipeline_id)) as pipeline_url,\n  count(*) as failed_tests\nFROM test_metrics.blocking_test_failures_mv\n" + commonWhereClause + '\nGROUP BY ci_server_url, ci_pipeline_id, ci_project_path, run_type\nHAVING failed_tests > 0\nORDER BY time DESC\nLIMIT 100',
    overrides=[
      {
        matcher: { id: 'byName', options: 'pipeline_url' },
        properties: [
          {
            id: 'links',
            value: [
              {
                targetBlank: true,
                title: 'Pipeline',
                url: '${__data.fields.pipeline_url}',
              },
            ],
          },
        ],
      },
    ],
  ),
  gridPos={ h: 8, w: 24, x: 0, y: 8 },
)
.addPanel(
  {
    type: 'timeseries',
    title: 'passed/failed/pending',
    datasource: clickhouseDatasource,
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
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
            { color: 'red', value: 80 },
          ],
        },
        unit: 'short',
      },
      overrides: [],
    },
    options: {
      legend: { calcs: ['mean'], displayMode: 'table', placement: 'bottom', showLegend: true },
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        datasource: clickhouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: testSuiteSummarySql,
        refId: 'A',
      },
    ],
    transformations: [
      {
        id: 'filterFieldsByName',
        options: {
          include: {
            names: ['time', 'passed', 'failed', 'pending', 'retried'],
          },
        },
      },
    ],
  },
  gridPos={ h: 10, w: 13, x: 0, y: 16 },
)
.addPanel(
  {
    type: 'timeseries',
    title: 'failure rate',
    datasource: clickhouseDatasource,
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
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
            { color: 'red', value: 80 },
          ],
        },
        unit: 'percentunit',
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'failure rate' },
          properties: [
            { id: 'color', value: { fixedColor: 'dark-red', mode: 'fixed' } },
          ],
        },
      ],
    },
    options: {
      legend: { calcs: ['mean'], displayMode: 'table', placement: 'bottom', showLegend: true },
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        datasource: clickhouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: testSuiteSummarySql,
        refId: 'A',
      },
    ],
    transformations: [
      {
        id: 'calculateField',
        options: {
          alias: 'failure rate',
          binary: {
            left: { matcher: { id: 'byName', options: 'failed' } },
            operator: '/',
            right: { matcher: { id: 'byName', options: 'executed' } },
          },
          mode: 'binary',
          reduce: { reducer: 'sum' },
        },
      },
      {
        id: 'filterFieldsByName',
        options: {
          include: {
            names: ['time', 'failure rate'],
          },
        },
      },
    ],
  },
  gridPos={ h: 10, w: 11, x: 13, y: 16 },
)
.addPanel(
  textPanel('Runtime of all executed tests in a single pipeline for specific test type. This time is indicative of how much compute time is spent on execution rather than how fast feedback is received.'),
  gridPos={ h: 3, w: 24, x: 0, y: 26 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='Total Runtime',
    rawSql='SELECT\n  $__timeInterval(timestamp) as time,\n  avg(pipeline_runtime) as test_runtime\nFROM (\n  SELECT\n    timestamp,\n    ci_pipeline_id,\n    sum(run_time) / 1000 as pipeline_runtime\n  FROM test_metrics.test_results_hourly_overview_mv\n  ' + commonWhereClause + '\n  GROUP BY timestamp, ci_pipeline_id\n)\nGROUP BY time\nORDER BY time',
    unit='s',
    description='Sum of all test runtimes in test suite',
  ),
  gridPos={ h: 9, w: 24, x: 0, y: 29 },
)
.addPanel(
  {
    type: 'stat',
    title: 'Average Test Suite Total Runtime',
    datasource: clickhouseDatasource,
    description: 'Average Test Suite Total Runtime for Current Week',
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
          ],
        },
        unit: 's',
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'test_runtime' },
          properties: [
            { id: 'color', value: { fixedColor: '#6f6f75', mode: 'fixed' } },
          ],
        },
      ],
    },
    options: {
      colorMode: 'value',
      graphMode: 'none',
      justifyMode: 'auto',
      orientation: 'auto',
      percentChangeColorMode: 'inverted',
      reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
      showPercentChange: true,
      textMode: 'auto',
      wideLayout: true,
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        datasource: clickhouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: 'SELECT\n  toStartOfWeek(timestamp) AS time,\n  avg(pipeline_runtime) as test_runtime\nFROM (\n  SELECT\n    timestamp,\n    ci_pipeline_id,\n    sum(run_time) / 1000 as pipeline_runtime\n  FROM test_metrics.test_results_hourly_overview_mv\n  ' + commonWhereClause + '\n  GROUP BY timestamp, ci_pipeline_id\n)\nGROUP BY time\nORDER BY time',
        refId: 'A',
      },
    ],
  },
  gridPos={ h: 9, w: 7, x: 0, y: 38 },
)
.addPanel(
  {
    datasource: clickhouseDatasource,
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisCenteredZero: false,
          axisColorMode: 'text',
          axisLabel: '',
          axisPlacement: 'auto',
          fillOpacity: 80,
          gradientMode: 'none',
          hideFrom: {
            legend: false,
            tooltip: false,
            viz: false,
          },
          lineWidth: 1,
          scaleDistribution: { type: 'linear' },
          thresholdsStyle: { mode: 'off' },
        },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green', value: 0 },
            { color: 'red', value: 80 },
          ],
        },
        unit: 's',
      },
      overrides: [],
    },
    options: {
      barRadius: 0,
      barWidth: 0.97,
      fullHighlight: false,
      groupWidth: 0.7,
      legend: {
        calcs: [],
        displayMode: 'list',
        placement: 'bottom',
        showLegend: true,
      },
      orientation: 'auto',
      showValue: 'auto',
      stacking: 'none',
      tooltip: {
        hideZeros: false,
        mode: 'single',
        sort: 'none',
      },
      xTickLabelRotation: 0,
      xTickLabelSpacing: 0,
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        datasource: clickhouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: 'SELECT\n  toStartOfWeek(timestamp) AS time,\n  avg(pipeline_runtime) as test_runtime\nFROM (\n  SELECT\n    timestamp,\n    ci_pipeline_id,\n    sum(run_time) / 1000 as pipeline_runtime\n  FROM test_metrics.test_results_hourly_overview_mv\n  ' + commonWhereClause + '\n  GROUP BY timestamp, ci_pipeline_id\n)\nGROUP BY time\nORDER BY time',
        refId: 'A',
      },
    ],
    title: 'Average Total Test Suite Runtime',
    type: 'barchart',
  },
  gridPos={ h: 9, w: 17, x: 7, y: 38 },
)
