local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;

local backendStrategies = ['coverage', 'described_class', 'duo'];
local frontendStrategies = ['jest_built_in'];

local testCountSql(testType, strategy) = |||
  SELECT
      toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,
      avg(predicted_test_files_count) AS average,
      quantile(0.50)(predicted_test_files_count) AS p50,
      quantile(0.80)(predicted_test_files_count) AS p80,
      quantile(0.90)(predicted_test_files_count) AS p90
  FROM test_metrics.predictive_tests
  WHERE
      $__timeFilter(timestamp)
      AND test_type = '%s'
      AND strategy = '%s'
  GROUP BY time
  ORDER BY time
||| % [testType, strategy];

local testRuntimeSql(testType, strategy) = |||
  SELECT
      toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,
      avg(projected_test_runtime_seconds) AS average,
      quantile(0.50)(projected_test_runtime_seconds) AS p50,
      quantile(0.80)(projected_test_runtime_seconds) AS p80,
      quantile(0.90)(projected_test_runtime_seconds) AS p90
  FROM test_metrics.predictive_tests
  WHERE
      $__timeFilter(timestamp)
      AND test_type = '%s'
      AND strategy = '%s'
  GROUP BY time
  ORDER BY time
||| % [testType, strategy];

local missedFailuresPerStrategySql(testType, strategy) = |||
  SELECT
      toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,
      avg(missed_failing_test_files) AS average,
      quantile(0.50)(missed_failing_test_files) AS p50,
      quantile(0.80)(missed_failing_test_files) AS p80,
      quantile(0.90)(missed_failing_test_files) AS p90
  FROM test_metrics.predictive_tests
  WHERE
      $__timeFilter(timestamp)
      AND test_type = '%s'
      AND strategy = '%s'
  GROUP BY time
  ORDER BY time
||| % [testType, strategy];

local missedFailuresSql(testType, strategies) =
  local strategyColumns = std.join(
    ',\n    ',
    [
      "countIf(strategy = '%s' AND missed_failing_test_files > 0) AS %s" % [s, s]
      for s in strategies
    ]
  );
  |||
    SELECT
        toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,
        %s
    FROM test_metrics.predictive_tests
    WHERE
        $__timeFilter(timestamp)
        AND test_type = '%s'
    GROUP BY time
    ORDER BY time
  ||| % [strategyColumns, testType];

local missedFailuresTableSql(testType, strategy) = |||
  SELECT
      timestamp,
      missed_failing_test_files AS missed_failures,
      predicted_failing_test_files AS predicted_failures,
      concat('https://gitlab.com/', ci_project_path, '/-/pipelines/', toString(ci_pipeline_id)) AS pipeline_url
  FROM test_metrics.predictive_tests
  WHERE
      $__timeFilter(timestamp)
      AND test_type = '%s'
      AND strategy = '%s'
      AND missed_failing_test_files > 0
  ORDER BY timestamp DESC
  LIMIT 100
||| % [testType, strategy];

local selectedTestCountTableSql(testType, strategy) = |||
  SELECT
      timestamp,
      predicted_test_files_count AS selected_test_count,
      projected_test_runtime_seconds AS projected_runtime,
      concat('https://gitlab.com/', ci_project_path, '/-/pipelines/', toString(ci_pipeline_id)) AS pipeline_url
  FROM test_metrics.predictive_tests
  WHERE
      $__timeFilter(timestamp)
      AND test_type = '%s'
      AND strategy = '%s'
  ORDER BY predicted_test_files_count DESC
  LIMIT 100
||| % [testType, strategy];

local panelHeight = 10;
local tableHeight = 10;
local statHeight = 4;

local pipelineUrlOverride = {
  matcher: { id: 'byName', options: 'pipeline_url' },
  properties: [
    { id: 'custom.minWidth', value: 400 },
    {
      id: 'links',
      value: [
        {
          targetBlank: true,
          title: 'Open Pipeline',
          url: '${__value.text}',
        },
      ],
    },
  ],
};

local timestampOverride = {
  matcher: { id: 'byName', options: 'timestamp' },
  properties: [
    { id: 'custom.width', value: 200 },
  ],
};

local missedFailuresOverride = {
  matcher: { id: 'byName', options: 'missed_failures' },
  properties: [
    { id: 'custom.width', value: 130 },
    { id: 'custom.align', value: 'center' },
  ],
};

local predictedFailuresOverride = {
  matcher: { id: 'byName', options: 'predicted_failures' },
  properties: [
    { id: 'custom.width', value: 140 },
    { id: 'custom.align', value: 'center' },
  ],
};

local selectedTestCountOverride = {
  matcher: { id: 'byName', options: 'selected_test_count' },
  properties: [
    { id: 'custom.width', value: 150 },
    { id: 'custom.align', value: 'center' },
  ],
};

local projectedRuntimeOverride = {
  matcher: { id: 'byName', options: 'projected_runtime' },
  properties: [
    { id: 'custom.width', value: 150 },
    { id: 'custom.align', value: 'center' },
    { id: 'unit', value: 's' },
  ],
};

local testCountTableOverrides = [
  timestampOverride,
  selectedTestCountOverride,
  projectedRuntimeOverride,
  pipelineUrlOverride,
];

local missedFailuresTableOverrides = [
  timestampOverride,
  missedFailuresOverride,
  predictedFailuresOverride,
  pipelineUrlOverride,
];

local maxTestCountSql(testType, strategies) =
  local cols = std.join(
    ',\n    ',
    ["maxIf(predicted_test_files_count, strategy = '%s') AS %s" % [s, s] for s in strategies]
  );
  |||
    SELECT
        %s
    FROM test_metrics.predictive_tests
    WHERE
        $__timeFilter(timestamp)
        AND test_type = '%s'
  ||| % [cols, testType];

local maxMissedFailuresSql(testType, strategies) =
  local cols = std.join(
    ',\n    ',
    ["maxIf(missed_failing_test_files, strategy = '%s') AS %s" % [s, s] for s in strategies]
  );
  |||
    SELECT
        %s
    FROM test_metrics.predictive_tests
    WHERE
        $__timeFilter(timestamp)
        AND test_type = '%s'
  ||| % [cols, testType];

local sectionStatPanels(testType, strategies, yOffset) = [
  panels.statPanel(
    title='Max Predicted Tests',
    rawSql=maxTestCountSql(testType, strategies),
  ) { gridPos: { h: statHeight, w: 12, x: 0, y: yOffset } },
  panels.statPanel(
    title='Max Missed Failures',
    rawSql=maxMissedFailuresSql(testType, strategies),
  ) { gridPos: { h: statHeight, w: 12, x: 12, y: yOffset } },
];

local strategyPanels(testType, strategy, yOffset) = [
  panels.timeSeriesPanel(
    title='Selected Test Count — %s' % strategy,
    rawSql=testCountSql(testType, strategy),
    legendCalcs=['mean'],
  ) { gridPos: { h: panelHeight, w: 12, x: 0, y: yOffset } },
  panels.timeSeriesPanel(
    title='Total Test Runtime — %s' % strategy,
    rawSql=testRuntimeSql(testType, strategy),
    unit='s',
    legendCalcs=['mean'],
  ) { gridPos: { h: panelHeight, w: 12, x: 12, y: yOffset } },
  panels.timeSeriesPanel(
    title='Missed Test Failures — %s' % strategy,
    rawSql=missedFailuresPerStrategySql(testType, strategy),
    legendCalcs=['mean'],
  ) { gridPos: { h: panelHeight, w: 24, x: 0, y: yOffset + panelHeight } },
  panels.tablePanel(
    title='Selected Test Count — %s (Details)' % strategy,
    rawSql=selectedTestCountTableSql(testType, strategy),
    sortBy=[{ displayName: 'selected_test_count', desc: true }],
    overrides=testCountTableOverrides,
  ) { gridPos: { h: tableHeight, w: 12, x: 0, y: yOffset + (2 * panelHeight) } },
  panels.tablePanel(
    title='Missed Failures — %s (Details)' % strategy,
    rawSql=missedFailuresTableSql(testType, strategy),
    sortBy=[{ displayName: 'timestamp', desc: true }],
    overrides=missedFailuresTableOverrides,
  ) { gridPos: { h: tableHeight, w: 12, x: 12, y: yOffset + (2 * panelHeight) } },
];

local panelsPerStrategy = (2 * panelHeight) + tableHeight;

local backendRowY = 0;
local backendStatsY = backendRowY + 1;
local backendStatPanels = sectionStatPanels('backend', backendStrategies, backendStatsY);
local backendPanelsStartY = backendStatsY + statHeight;

local backendStrategyPanels = std.flattenArrays([
  strategyPanels('backend', backendStrategies[i], backendPanelsStartY + (i * panelsPerStrategy))
  for i in std.range(0, std.length(backendStrategies) - 1)
]);

local backendMissedChartY = backendPanelsStartY + (std.length(backendStrategies) * panelsPerStrategy);

local frontendRowY = backendMissedChartY + panelHeight;
local frontendStatsY = frontendRowY + 1;
local frontendStatPanels = sectionStatPanels('frontend', frontendStrategies, frontendStatsY);
local frontendPanelsStartY = frontendStatsY + statHeight;

local frontendStrategyPanels = std.flattenArrays([
  strategyPanels('frontend', frontendStrategies[i], frontendPanelsStartY + (i * panelsPerStrategy))
  for i in std.range(0, std.length(frontendStrategies) - 1)
]);

local frontendMissedChartY = frontendPanelsStartY + (std.length(frontendStrategies) * panelsPerStrategy);

local dashboard =
  (basic.dashboard(
     title='Predictive Tests',
     tags=config.testMetricsTags,
     time_from='now-30d',
     time_to='now',
     includeEnvironmentTemplate=false,
     includeStandardEnvironmentAnnotations=false,
     includePrometheusDatasourceTemplate=false
   ) + { timezone: 'browser' })
  .addTemplate(
    template.custom(
      'aggregation',
      'day,week,month',
      'day',
    ),
  )
  .addPanel(
    row.new(title='RSpec Backend Tests', collapse=false),
    gridPos={ x: 0, y: backendRowY, w: 24, h: 1 },
  );

local withBackendStatPanels = std.foldl(
  function(d, p) d.addPanel(p, gridPos=p.gridPos),
  backendStatPanels,
  dashboard,
);

local withBackendStrategyPanels = std.foldl(
  function(d, p) d.addPanel(p, gridPos=p.gridPos),
  backendStrategyPanels,
  withBackendStatPanels,
);

local withBackendMissedChart = withBackendStrategyPanels.addPanel(
  panels.timeSeriesPanel(
    title='Pipelines with Missed Failures — RSpec',
    rawSql=missedFailuresSql('backend', backendStrategies),
    legendCalcs=['mean'],
  ),
  gridPos={ h: panelHeight, w: 24, x: 0, y: backendMissedChartY },
);

local withFrontendRow = withBackendMissedChart.addPanel(
  row.new(title='Jest Frontend Tests', collapse=false),
  gridPos={ x: 0, y: frontendRowY, w: 24, h: 1 },
);

local withFrontendStatPanels = std.foldl(
  function(d, p) d.addPanel(p, gridPos=p.gridPos),
  frontendStatPanels,
  withFrontendRow,
);

local withFrontendStrategyPanels = std.foldl(
  function(d, p) d.addPanel(p, gridPos=p.gridPos),
  frontendStrategyPanels,
  withFrontendStatPanels,
);

withFrontendStrategyPanels.addPanel(
  panels.timeSeriesPanel(
    title='Pipelines with Missed Failures — Jest',
    rawSql=missedFailuresSql('frontend', frontendStrategies),
    legendCalcs=['mean'],
  ),
  gridPos={ h: panelHeight, w: 24, x: 0, y: frontendMissedChartY },
)
