local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';
local row = grafana.row;
local template = grafana.template;

local dashboardDatasource = { type: 'datasource', uid: '-- Dashboard --' };

local statPanelFromDashboard(title, description, sourceStableId, unit='percentunit', thresholdSteps=[], calcs=['mean']) = {
  type: 'stat',
  title: title,
  datasource: dashboardDatasource,
  description: description,
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: { mode: 'absolute', steps: thresholdSteps },
      unit: unit,
    },
    overrides: [],
  },
  options: {
    colorMode: 'value',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'auto',
    percentChangeColorMode: 'standard',
    reduceOptions: { calcs: calcs, fields: '', values: false },
    showPercentChange: false,
    textMode: 'auto',
    wideLayout: true,
  },
  targets: [{
    datasource: dashboardDatasource,
    panelId: stableIds.hashStableId(sourceStableId),
    refId: 'A',
  }],
};

local fileFailureRetryTimeseries = panels.timeSeriesPanel(
  'test file daily failure and retry  rate',
  rawSql="SELECT\n  $__timeInterval(timestamp) as timestamp,\n  round(sum(jobs_with_failures) / nullIf(sum(total_jobs), 0), 2) as failure_rate,\n  round(sum(jobs_with_retries) / nullIf(sum(total_jobs), 0), 2) as retry_rate\nFROM test_metrics.test_results_test_file_failure_counts FINAL\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND group IN (${group:singlequote})\n  AND file_path = '${file_path}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY timestamp",
  unit='percentunit',
  description='file failure and retry rate where:\n* failure_rate - test failures\n* retry_rate - test passed on retry',
) + {
  stableId: 'file-failure-retry-rate',
  fieldConfig+: {
    overrides: [{
      matcher: { id: 'byName', options: 'failure_rate' },
      properties: [{ id: 'color', value: { fixedColor: 'dark-red', mode: 'fixed' } }],
    }],
  },
};

local failureRetryRatesStat = statPanelFromDashboard(
  'failure and retry rates',
  'average file failure and retry rate over the whole time period',
  'file-failure-retry-rate',
  unit='percentunit',
  thresholdSteps=[{ color: 'green', value: 0 }, { color: 'red', value: 0.005 }],
);

local failureBreakdownText = panels.textPanel(content='# Individual test failure breakdown');

local specFailureRateTable = panels.tablePanel(
  'test failure rates',
  "SELECT\n  test_location,\n  id as test_id,\n  hash,\n  sum(jobs_with_failures) as jobs_with_failure,\n  sum(jobs_with_retries) as jobs_with_retry,\n  sum(total_jobs) as jobs_total,\n  round(sum(jobs_with_failures) / nullIf(sum(total_jobs), 0), 2) as failure_rate,\n  round(sum(jobs_with_retries) / nullIf(sum(total_jobs), 0), 2) as retry_rate\nFROM test_metrics.test_results_spec_failure_counts\nFINAL\nWHERE ci_project_path = '${project}'\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND file_path = '${file_path}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY hash, test_location, id\nHAVING jobs_with_failure > 0 OR jobs_with_retry > 0\nORDER BY jobs_with_failure DESC, failure_rate DESC",
  transformations=[
    {
      id: 'organize',
      options: {
        excludeByName: { hash: true },
        includeByName: {},
        indexByName: {
          failure_rate: 2,
          hash: 4,
          jobs_total: 7,
          jobs_with_failure: 5,
          jobs_with_retry: 6,
          retry_rate: 3,
          test_id: 1,
          test_location: 0,
        },
        renameByName: {},
      },
    },
  ],
  overrides=[
    {
      matcher: { id: 'byName', options: 'test_location' },
      properties: [{ id: 'custom.width', value: 600 }],
    },
    {
      matcher: { id: 'byName', options: 'failure_rate' },
      properties: [{ id: 'unit', value: 'percentunit' }],
    },
    {
      matcher: { id: 'byName', options: 'retry_rate' },
      properties: [{ id: 'unit', value: 'percentunit' }],
    },
  ],
);

local failureRateTimeseries = (panels.timeSeriesPanel(
                                 'failure rate',
                                 rawSql="SELECT\n  $__timeInterval(timestamp) as timestamp,\n  id,\n  round(sum(jobs_with_failures) / nullIf(sum(total_jobs), 0), 2) as failure_rate\nFROM test_metrics.test_results_spec_failure_counts\nFINAL\nWHERE ci_project_path = '${project}'\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND file_path = '${file_path}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY timestamp, hash, id\nORDER BY timestamp, hash",
                                 unit='percentunit',
                                 displayName='${__field.labels.id}',
                               )) + {
  fieldConfig+: {
    defaults+: {
      max: 1,
    },
  },
  targets: [{
    editorType: 'sql',
    format: 0,
    queryType: 'timeseries',
    rawSql: "SELECT\n  $__timeInterval(timestamp) as timestamp,\n  id,\n  round(sum(jobs_with_failures) / nullIf(sum(total_jobs), 0), 2) as failure_rate\nFROM test_metrics.test_results_spec_failure_counts\nFINAL\nWHERE ci_project_path = '${project}'\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND file_path = '${file_path}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY timestamp, hash, id\nORDER BY timestamp, hash",
    refId: 'A',
  }],
};

local retryRateTimeseries = (panels.timeSeriesPanel(
                               'retry rate',
                               rawSql="SELECT\n  $__timeInterval(timestamp) as timestamp,\n  id,\n  round(sum(jobs_with_retries) / nullIf(sum(total_jobs), 0), 2) as retry_rate\nFROM test_metrics.test_results_spec_failure_counts\nFINAL\nWHERE ci_project_path = '${project}'\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND file_path = '${file_path}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY timestamp, hash, id\nORDER BY timestamp, hash",
                               unit='percentunit',
                               displayName='${__field.labels.id}',
                             )) + {
  fieldConfig+: {
    defaults+: {
      max: 1,
    },
  },
  targets: [{
    editorType: 'sql',
    format: 0,
    queryType: 'timeseries',
    rawSql: "SELECT\n  $__timeInterval(timestamp) as timestamp,\n  id,\n  round(sum(jobs_with_retries) / nullIf(sum(total_jobs), 0), 2) as retry_rate\nFROM test_metrics.test_results_spec_failure_counts\nFINAL\nWHERE ci_project_path = '${project}'\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND file_path = '${file_path}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY timestamp, hash, id\nORDER BY timestamp, hash",
    refId: 'A',
  }],
};

local lastFailuresTable = panels.tablePanel(
  'last failures',
  "SELECT\n    timestamp,\n    location,\n    concat(ci_server_url, '/', ci_project_path, '/-/jobs/', toString(ci_job_id)) as job_url\nFROM test_metrics.blocking_test_failures_mv\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND file_path = '${file_path}'\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND $__timeFilter(timestamp)\nORDER BY timestamp DESC\nLIMIT 50",
  transformations=[
    {
      id: 'filterFieldsByName',
      options: {
        include: {
          names: ['timestamp', 'location', 'job_url'],
        },
      },
    },
  ],
  overrides=[
    {
      matcher: { id: 'byName', options: 'location' },
      properties: [
        { id: 'custom.width', value: 479 },
        {
          id: 'links',
          value: [{
            targetBlank: true,
            title: 'Job Url',
            url: '${__data.fields.job_url}',
          }],
        },
      ],
    },
    {
      matcher: { id: 'byName', options: 'job_url' },
      properties: [{ id: 'custom.hideFrom.viz', value: true }],
    },
  ],
);

local exceptionDistributionPie = panels.piePanel(
  'exception distribution',
  "SELECT\n    arrayJoin(exception_classes) as exception,\n    count(*)\nFROM test_metrics.blocking_test_failures_mv\nWHERE ci_project_path = '${project}'\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND file_path = '${file_path}'\n  AND $__timeFilter(timestamp)\nGROUP BY exception",
);

local fileRuntimeTimeseries = panels.timeSeriesPanel(
  'file runtime',
  rawSql="SELECT\n  $__timeInterval(timestamp) as timestamp,\n  avg(avg_file_runtime) as runtime\nFROM test_metrics.test_results_passed_test_file_runtime FINAL\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND group IN (${group:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND file_path = '${file_path}'\n  AND $__timeFilter(timestamp)\nGROUP BY timestamp",
  unit='ms',
  description='total runtime of test file',
) + {
  stableId: 'file-runtime',
};

local testCountStat = panels.statPanel(
  'test count',
  rawSql="SELECT\n  $__timeInterval(timestamp) as time,\n  uniqExact(hash) as unique_test_count\nFROM test_metrics.test_results_passed_test_runtime FINAL\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND group IN (${group:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND file_path = '${file_path}'\n  AND $__timeFilter(timestamp)\nGROUP BY time\nORDER BY time;",
  description='total amount of tests in the test file',
  graphMode='area',
);

local fileRuntimeStat = statPanelFromDashboard(
  'file runtime min',
  'average runtime of the whole test file',
  'file-runtime',
  unit='ms',
  thresholdSteps=[{ color: 'green', value: 0 }, { color: 'red', value: 80 }],
) + {
  fieldConfig+: {
    defaults+: {
      color: { fixedColor: '#95959f', mode: 'fixed' },
    },
  },
};

local runtimeBreakdownText = panels.textPanel(content='# Individual test runtime breakdown');

local specRuntimesTable = panels.tablePanel(
  'spec runtimes',
  "SELECT\n  any(location) as test_location,\n  any(id) as id,\n  hash,\n  round(avg(avg_runtime) / 1000.0, 2) as runtime_seconds\nFROM test_metrics.test_results_passed_test_runtime FINAL\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND group IN (${group:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND file_path = '${file_path}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY hash\nORDER BY runtime_seconds DESC\nLIMIT 100;",
  description='Average runtime for each test',
  transformations=[
    {
      id: 'organize',
      options: {
        excludeByName: { hash: true },
        includeByName: {},
        indexByName: {},
        renameByName: {},
      },
    },
  ],
  overrides=[
    {
      matcher: { id: 'byName', options: 'runtime_seconds' },
      properties: [
        { id: 'custom.width', value: 150 },
        { id: 'custom.align', value: 'center' },
      ],
    },
  ],
);

local specRuntimesTimeseries = {
  type: 'timeseries',
  title: 'spec runtimes',
  datasource: panels.clickHouseDatasource,
  description: 'Average runtime for 100 slowest tests',
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
      displayName: '${__field.labels.test_location}',
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
      unit: 's',
    },
    overrides: [],
  },
  options: {
    legend: {
      calcs: ['mean'],
      displayMode: 'table',
      placement: 'right',
      showLegend: true,
      sortBy: 'Mean',
      sortDesc: true,
    },
    tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
  },
  targets: [
    {
      datasource: panels.clickHouseDatasource,
      editorType: 'sql',
      format: 0,
      queryType: 'timeseries',
      rawSql: "SELECT\n  $__timeInterval(timestamp) as time,\n  any(location) as test_location,\n  hash,\n  round(avg(avg_runtime) / 1000.0, 2) as runtime\nFROM test_metrics.test_results_passed_test_runtime FINAL\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND group IN (${group:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND file_path = '${file_path}'\n  AND $__timeFilter(timestamp)\n  AND hash IN (\n    SELECT hash\n    FROM test_metrics.test_results_passed_test_runtime FINAL\n    WHERE ci_project_path = '${project}'\n      AND run_type IN (${run_type:singlequote})\n      AND group IN (${group:singlequote})\n      AND pipeline_type IN (${pipeline_type:singlequote})\n      AND file_path = '${file_path}'\n      AND $__timeFilter(timestamp)\n    GROUP BY hash\n    ORDER BY avg(avg_runtime) DESC\n    LIMIT 100\n  )\nGROUP BY hash, time\nORDER BY time, hash;",
      refId: 'A',
    },
  ],
  transformations: [
    {
      id: 'organize',
      options: {
        excludeByName: { hash: true },
        includeByName: {},
        indexByName: {},
        renameByName: {},
      },
    },
  ],
};

(basic.dashboard(
   title='Single Test Overview',
   tags=config.testMetricsTags,
   time_from='now-30d',
   time_to='now',
   includeEnvironmentTemplate=false,
   includeStandardEnvironmentAnnotations=false,
   includePrometheusDatasourceTemplate=false,
 ) + { timezone: 'browser' })
.addTemplate(
  template.new(
    'project',
    panels.clickHouseDatasource,
    "SELECT DISTINCT ci_project_path\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE pipeline_type = 'default_branch_pipeline'\n  AND $__timeFilter(timestamp)\nORDER BY ci_project_path",
    current='gitlab-org/gitlab',
    includeAll=false,
    refresh='load',
  ),
)
.addTemplate(
  template.new(
    'run_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT run_type\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE ci_project_path = '${project}'\n  AND $__timeFilter(timestamp)\nORDER BY run_type",
    current='backend-rspec-tests',
    includeAll=false,
    refresh='load',
  ),
)
.addTemplate(
  template.new(
    'pipeline_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT pipeline_type\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE ci_project_path = '${project}'\nAND run_type IN (${run_type:singlequote})\nAND $__timeFilter(timestamp)\nAND pipeline_type != 'any'\nAND pipeline_type != 'unknown'\nORDER BY run_type",
    current='All',
    includeAll=true,
    multi=true,
    refresh='load',
  ),
)
.addTemplate(
  template.new(
    'group',
    panels.clickHouseDatasource,
    "SELECT DISTINCT group\nFROM test_metrics.test_results_hourly_ownership_data_mv\nWHERE ci_project_path = '${project}'\nAND run_type IN (${run_type:singlequote})\nAND pipeline_type IN (${pipeline_type:singlequote})\nAND $__timeFilter(timestamp)\nORDER BY group",
    current='All',
    includeAll=true,
    refresh='load',
  ),
)
.addTemplate(
  template.new(
    'file_path',
    panels.clickHouseDatasource,
    "SELECT arrayJoin(groupUniqArrayMerge(file_paths)) as file_path\nFROM test_metrics.test_results_hourly_file_paths_mv\nWHERE ci_project_path = '${project}'\nAND run_type IN (${run_type:singlequote})\nAND pipeline_type IN (${pipeline_type:singlequote})\nAND group IN (${group:singlequote})\nAND $__timeFilter(timestamp)\nORDER BY file_path",
    current='ee/spec/bin/custom_ability_spec.rb',
    includeAll=false,
    refresh='load',
  ),
)
.addPanel(
  row.new(title='Failure data', collapse=true)
  .addPanel(fileFailureRetryTimeseries, gridPos={ x: 0, y: 1, w: 18, h: 10 })
  .addPanel(failureRetryRatesStat, gridPos={ x: 18, y: 1, w: 6, h: 10 })
  .addPanel(failureBreakdownText, gridPos={ x: 0, y: 11, w: 24, h: 2 })
  .addPanel(specFailureRateTable, gridPos={ x: 0, y: 13, w: 24, h: 10 })
  .addPanel(failureRateTimeseries, gridPos={ x: 0, y: 23, w: 24, h: 10 })
  .addPanel(retryRateTimeseries, gridPos={ x: 0, y: 33, w: 24, h: 10 })
  .addPanel(lastFailuresTable, gridPos={ x: 0, y: 43, w: 12, h: 9 })
  .addPanel(exceptionDistributionPie, gridPos={ x: 12, y: 43, w: 12, h: 9 }),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanel(
  row.new(title='Runtime data', collapse=true)
  .addPanel(fileRuntimeTimeseries, gridPos={ x: 0, y: 2, w: 20, h: 12 })
  .addPanel(testCountStat, gridPos={ x: 20, y: 2, w: 4, h: 6 })
  .addPanel(fileRuntimeStat, gridPos={ x: 20, y: 8, w: 4, h: 6 })
  .addPanel(runtimeBreakdownText, gridPos={ x: 0, y: 14, w: 24, h: 2 })
  .addPanel(specRuntimesTable, gridPos={ x: 0, y: 16, w: 24, h: 10 })
  .addPanel(specRuntimesTimeseries, gridPos={ x: 0, y: 26, w: 24, h: 15 }),
  gridPos={ x: 0, y: 1, w: 24, h: 1 },
)
.trailer()
