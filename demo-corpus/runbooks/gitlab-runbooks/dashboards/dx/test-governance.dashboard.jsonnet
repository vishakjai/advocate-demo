local config = import './common/config.libsonnet';
local sql = import './common/sql.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;

local stableIds = import 'stable-ids/stable-ids.libsonnet';

local datasourceUid = config.datasourceUid;
local clickHouseDatasource = { type: 'grafana-clickhouse-datasource', uid: datasourceUid };
local dashboardDatasource = { type: 'datasource', uid: '-- Dashboard --' };

local vars = {
  finished_pipelines_mv: 'ci_metrics.finished_pipelines_mv',
  build_metrics_table: 'ci_metrics.build_metrics',
  canonicalProjectPath: sql.gitlabProjectPath,
  fossProjectPath: sql.gitlabFossProjectPath,
  canonicalProjectPathFilter: "project_path = '" + sql.gitlabProjectPath + "'",
};

local weeklyMrPipelineFailureRateSql = |||
  SELECT
    toStartOfInterval(created_at, INTERVAL 1 WEEK) AS time,
    countIf(status = 'failed' AND pre_merge_check = false) * 100.0 / nullIf(countIf(pre_merge_check = false), 0) AS mr
  FROM %(finished_pipelines_mv)s
  WHERE $__timeFilter(created_at)
    AND %(canonicalProjectPathFilter)s
    AND source = 'merge_request_event'
    AND status != 'canceled'
    AND tier != 0
  GROUP BY time
  ORDER BY time
||| % vars;

local weeklyMasterPipelineFailureRateSql = |||
  SELECT
    toStartOfInterval(created_at, INTERVAL 1 WEEK) AS time,
    countIf(status = 'failed' AND source = 'schedule') * 100.0 / nullIf(countIf(source = 'schedule'), 0) AS master
  FROM %(finished_pipelines_mv)s
  WHERE $__timeFilter(created_at)
    AND %(canonicalProjectPathFilter)s
    AND source != 'parent_pipeline'
    AND ref = 'master'
  GROUP BY time
  ORDER BY time
||| % vars;

local weeklyMrPipelineDurationP80Sql = |||
  SELECT
    toStartOfInterval(created_at, INTERVAL 1 WEEK) AS time,
    quantile(0.80)(duration) AS mr
  FROM %(finished_pipelines_mv)s
  WHERE $__timeFilter(created_at)
    AND %(canonicalProjectPathFilter)s
    AND source = 'merge_request_event'
    AND pre_merge_check = false
    AND status != 'canceled'
    AND tier IN (1, 2, 3)
  GROUP BY time
  ORDER BY time
||| % vars;

local weeklyMrPipelineDurationP80PerTierSql = |||
  SELECT
      toStartOfInterval(created_at, INTERVAL 1 WEEK) AS time,
      quantileIf(0.80)(duration, tier = 1) AS tier_1,
      quantileIf(0.80)(duration, tier = 2) AS tier_2,
      quantileIf(0.80)(duration, tier = 3) AS tier_3
  FROM %(finished_pipelines_mv)s
  WHERE
      $__timeFilter(created_at)
      AND %(canonicalProjectPathFilter)s
      AND source = 'merge_request_event'
      AND pre_merge_check = false
      AND status != 'canceled'
      AND tier IN (1, 2, 3)
  GROUP BY time
  ORDER BY time
||| % vars;

local weeklyMasterPipelineDurationP80Sql = |||
  SELECT
    toStartOfInterval(created_at, INTERVAL 1 WEEK) AS time,
    quantile(0.80)(duration) AS master
  FROM %(finished_pipelines_mv)s
  WHERE $__timeFilter(created_at)
    AND %(canonicalProjectPathFilter)s
    AND ref = 'master'
    AND source = 'schedule'
  GROUP BY time
  ORDER BY time
||| % vars;

local weeklyMrBackendTestCostP80Sql = |||
  WITH parent_pipelines AS (
    SELECT id, created_at
    FROM %(finished_pipelines_mv)s
    WHERE
      $__timeFilter(created_at)
      AND %(canonicalProjectPathFilter)s
      AND original_id = 0
      AND source = 'merge_request_event'
      AND pre_merge_check = false
  ),
  all_pipeline_ids AS (
    SELECT
      id AS parent_id,
      if(original_id = 0, id, original_id) AS actual_pipeline_id,
      project_id
    FROM %(finished_pipelines_mv)s
    WHERE
      $__timeFilter(created_at)
      AND id IN (SELECT id FROM parent_pipelines)
  ),
  rspec_costs AS (
    SELECT
      a.parent_id,
      sum(b.cost) AS total_rspec_cost
    FROM %(build_metrics_table)s b
    INNER JOIN all_pipeline_ids a
      ON b.pipeline_id = a.actual_pipeline_id
      AND b.project_id = a.project_id
    WHERE
      $__timeFilter(b.created_at)
      AND b.project_path IN ('%(canonicalProjectPath)s', '%(fossProjectPath)s')
      AND b.status IN ('success', 'failed', 'canceled', 'skipped')
      AND b.name LIKE 'rspec%%'
    GROUP BY a.parent_id
  )
  SELECT
    toStartOfInterval(p.created_at, INTERVAL 1 WEEK) AS time,
    quantile(0.80)(r.total_rspec_cost) AS mr
  FROM parent_pipelines p
  INNER JOIN rspec_costs r ON p.id = r.parent_id
  GROUP BY time
  ORDER BY time
||| % vars;

local weeklyMrBackendTestCostP80PerTierSql = |||
  WITH parent_pipelines AS (
    SELECT id, created_at, tier
    FROM %(finished_pipelines_mv)s
    WHERE
      $__timeFilter(created_at)
      AND %(canonicalProjectPathFilter)s
      AND original_id = 0
      AND source = 'merge_request_event'
      AND pre_merge_check = false
      AND tier IN (1, 2, 3)
  ),
  all_pipeline_ids AS (
    SELECT
      id AS parent_id,
      if(original_id = 0, id, original_id) AS actual_pipeline_id,
      project_id
    FROM %(finished_pipelines_mv)s
    WHERE
      $__timeFilter(created_at)
      AND id IN (SELECT id FROM parent_pipelines)
  ),
  rspec_costs AS (
    SELECT
      a.parent_id,
      sum(b.cost) AS total_rspec_cost
    FROM %(build_metrics_table)s b
    INNER JOIN all_pipeline_ids a
      ON b.pipeline_id = a.actual_pipeline_id
      AND b.project_id = a.project_id
    WHERE
      $__timeFilter(b.created_at)
      AND b.project_path IN ('%(canonicalProjectPath)s', '%(fossProjectPath)s')
      AND b.status IN ('success', 'failed', 'canceled', 'skipped')
      AND b.name LIKE 'rspec%%'
    GROUP BY a.parent_id
  )
  SELECT
    toStartOfInterval(p.created_at, INTERVAL 1 WEEK) AS time,
    quantileIf(0.80)(r.total_rspec_cost, p.tier = 1) AS tier_1,
    quantileIf(0.80)(r.total_rspec_cost, p.tier = 2) AS tier_2,
    quantileIf(0.80)(r.total_rspec_cost, p.tier = 3) AS tier_3
  FROM parent_pipelines p
  INNER JOIN rspec_costs r ON p.id = r.parent_id
  GROUP BY time
  ORDER BY time
||| % vars;

local weeklyMasterBackendTestCostP80Sql = |||
  WITH parent_pipelines AS (
    SELECT id, created_at
    FROM %(finished_pipelines_mv)s
    WHERE
      $__timeFilter(created_at)
      AND %(canonicalProjectPathFilter)s
      AND original_id = 0
      AND ref = 'master'
      AND source = 'schedule'
  ),
  all_pipeline_ids AS (
    SELECT
      id AS parent_id,
      if(original_id = 0, id, original_id) AS actual_pipeline_id,
      project_id
    FROM %(finished_pipelines_mv)s
    WHERE
      $__timeFilter(created_at)
      AND id IN (SELECT id FROM parent_pipelines)
  ),
  rspec_costs AS (
    SELECT
      a.parent_id,
      sum(b.cost) AS total_rspec_cost
    FROM %(build_metrics_table)s b
    INNER JOIN all_pipeline_ids a
      ON b.pipeline_id = a.actual_pipeline_id
      AND b.project_id = a.project_id
    WHERE
      $__timeFilter(b.created_at)
      AND b.project_path IN ('%(canonicalProjectPath)s', '%(fossProjectPath)s')
      AND b.status IN ('success', 'failed', 'canceled', 'skipped')
      AND b.name LIKE 'rspec%%'
    GROUP BY a.parent_id
  )
  SELECT
    toStartOfInterval(p.created_at, INTERVAL 1 WEEK) AS time,
    quantile(0.80)(r.total_rspec_cost) AS master
  FROM parent_pipelines p
  INNER JOIN rspec_costs r ON p.id = r.parent_id
  GROUP BY time
  ORDER BY time
||| % vars;

local statPanel(
  title,
  description,
  rawSql,
  gridPos,
  unit='percent',
  thresholdValue=5,
  greenFirst=true,
  showPercentChange=true,
  percentChangeInverted=true,
  stableId=null,
      ) = {
  [if stableId != null then 'stableId']: stableId,
  datasource: clickHouseDatasource,
  description: description,
  fieldConfig: {
    defaults: {
      thresholds: {
        mode: 'absolute',
        steps: if greenFirst then [
          { color: 'green', value: 0 },
          { color: 'red', value: thresholdValue },
        ] else [
          { color: 'red', value: 0 },
          { color: 'green', value: thresholdValue },
        ],
      },
      unit: unit,
    },
  },
  gridPos: gridPos,
  options: {
    graphMode: 'none',
    percentChangeColorMode: if percentChangeInverted then 'inverted' else 'standard',
    showPercentChange: showPercentChange,
  },
  targets: [{
    datasource: clickHouseDatasource,
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: rawSql,
    refId: 'A',
  }],
  title: title,
  type: 'stat',
};

local barChartPanelFromDashboard(
  title,
  sourceStableId,
  gridPos,
  unit='percent',
      ) = {
  datasource: dashboardDatasource,
  fieldConfig: {
    defaults: {
      custom: {
        fillOpacity: 80,
      },
      unit: unit,
    },
  },
  gridPos: gridPos,
  options: {
    legend: {
      calcs: ['lastNotNull', 'mean'],
      displayMode: 'table',
      placement: 'right',
    },
    showValue: 'always',
  },
  targets: [{
    datasource: dashboardDatasource,
    panelId: stableIds.hashStableId(sourceStableId),
    refId: 'A',
  }],
  title: title,
  type: 'barchart',
};

local headerText = {
  gridPos: { h: 3, w: 24, x: 0, y: 0 },
  options: {
    content: '# Key metrics related to CI/CD pipeline execution in **gitlab-org/gitlab** project',
    mode: 'markdown',
  },
  title: '',
  type: 'text',
};

local pipelineStabilityRow = row.new(title='Pipeline Stability', collapse=false);
local pipelineDurationRow = row.new(title='Pipeline Duration', collapse=false);
local testCostsRow = row.new(title='Test Costs', collapse=false);

local testCostsCalculationText = {
  gridPos: { h: 4, w: 24, x: 0, y: 56 },
  options: {
    content: '# Calculation\n\nBackend test execution cost breakdown per single pipeline execution. Cost is calculated by summing up run costs for all jobs which names start with "rspec". The calculation includes jobs triggered in child pipeline, including tests executed in "gitlab-org/gitlab-foss".',
    mode: 'markdown',
  },
  title: '',
  type: 'text',
};

local weeklyMrFailureRateStat = statPanel(
  title='Weekly MR Pipeline Failure Rate',
  description='Weekly failure rate for all merge request pipelines',
  rawSql=weeklyMrPipelineFailureRateSql,
  gridPos={ h: 10, w: 6, x: 0, y: 4 },
  unit='percent',
  thresholdValue=5,
  stableId='weekly-mr-failure-rate',
);

local weeklyMrFailureRateBar = barChartPanelFromDashboard(
  title='Weekly MR Pipeline Failure Rate',
  sourceStableId='weekly-mr-failure-rate',
  gridPos={ h: 10, w: 18, x: 6, y: 4 },
  unit='percent',
);

local weeklyMasterFailureRateStat = statPanel(
  title='Weekly Master Pipeline Failure Rate',
  description='Weekly failure rate for scheduled master pipelines',
  rawSql=weeklyMasterPipelineFailureRateSql,
  gridPos={ h: 10, w: 6, x: 0, y: 14 },
  unit='percent',
  thresholdValue=5,
  stableId='weekly-master-failure-rate',
);

local weeklyMasterFailureRateBar = barChartPanelFromDashboard(
  title='Weekly Master Pipeline Failure Rate',
  sourceStableId='weekly-master-failure-rate',
  gridPos={ h: 10, w: 18, x: 6, y: 14 },
  unit='percent',
);

local weeklyMrDurationStat = statPanel(
  title='Weekly MR P80 Pipeline Duration',
  description='P80 duration for merge request pipelines',
  rawSql=weeklyMrPipelineDurationP80Sql,
  gridPos={ h: 10, w: 6, x: 0, y: 25 },
  unit='s',
  thresholdValue=80,
  stableId='weekly-mr-duration',
);

local weeklyMrDurationBar = barChartPanelFromDashboard(
  title='Weekly MR P80 Pipeline Duration',
  sourceStableId='weekly-mr-duration',
  gridPos={ h: 10, w: 18, x: 6, y: 25 },
  unit='s',
);

local weeklyMrDurationPerTierStat = statPanel(
  title='Weekly MR P80 Pipeline Duration Per Tier',
  description='P80 duration for merge request pipelines',
  rawSql=weeklyMrPipelineDurationP80PerTierSql,
  gridPos={ h: 10, w: 6, x: 0, y: 35 },
  unit='s',
  thresholdValue=80,
  stableId='weekly-mr-duration-per-tier',
);

local weeklyMrDurationPerTierBar = barChartPanelFromDashboard(
  title='Weekly MR P80 Pipeline Duration Per Tier',
  sourceStableId='weekly-mr-duration-per-tier',
  gridPos={ h: 10, w: 18, x: 6, y: 35 },
  unit='s',
);

local weeklyMasterDurationStat = statPanel(
  title='Weekly Master P80 Pipeline Duration',
  description='P80 duration for scheduled master pipelines',
  rawSql=weeklyMasterPipelineDurationP80Sql,
  gridPos={ h: 10, w: 6, x: 0, y: 45 },
  unit='s',
  thresholdValue=80,
  stableId='weekly-master-duration',
);

local weeklyMasterDurationBar = barChartPanelFromDashboard(
  title='Weekly Master P80 Pipeline Duration',
  sourceStableId='weekly-master-duration',
  gridPos={ h: 10, w: 18, x: 6, y: 45 },
  unit='s',
);

local weeklyMrTestCostStat = statPanel(
  title='Weekly MR P80 Backend Test Cost',
  description='',
  rawSql=weeklyMrBackendTestCostP80Sql,
  gridPos={ h: 10, w: 6, x: 0, y: 60 },
  unit='currencyUSD',
  thresholdValue=80,
  stableId='weekly-mr-test-cost',
);

local weeklyMrTestCostBar = barChartPanelFromDashboard(
  title='Weekly MR P80 Backend Test Cost',
  sourceStableId='weekly-mr-test-cost',
  gridPos={ h: 10, w: 18, x: 6, y: 60 },
  unit='currencyUSD',
);

local weeklyMrTestCostPerTierStat = statPanel(
  title='Weekly MR P80 Backend Test Cost Per Tier',
  description='',
  rawSql=weeklyMrBackendTestCostP80PerTierSql,
  gridPos={ h: 10, w: 6, x: 0, y: 70 },
  unit='currencyUSD',
  thresholdValue=80,
  stableId='weekly-mr-test-cost-per-tier',
);

local weeklyMrTestCostPerTierBar = barChartPanelFromDashboard(
  title='Weekly MR P80 Backend Test Cost Per Tier',
  sourceStableId='weekly-mr-test-cost-per-tier',
  gridPos={ h: 10, w: 18, x: 6, y: 70 },
  unit='currencyUSD',
);

local weeklyMasterTestCostStat = statPanel(
  title='Weekly Master P80 Backend Test Cost',
  description='',
  rawSql=weeklyMasterBackendTestCostP80Sql,
  gridPos={ h: 10, w: 6, x: 0, y: 80 },
  unit='currencyUSD',
  thresholdValue=80,
  stableId='weekly-master-test-cost',
);

local weeklyMasterTestCostBar = barChartPanelFromDashboard(
  title='Weekly Master P80 Backend Test Cost',
  sourceStableId='weekly-master-test-cost',
  gridPos={ h: 10, w: 18, x: 6, y: 80 },
  unit='currencyUSD',
);

basic.dashboard(
  'Test Governance Key Metrics',
  tags=['test-governance'],
  time_from='now-30d',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  includePrometheusDatasourceTemplate=false,
)
.addPanels([
  headerText,
  pipelineStabilityRow { gridPos: { h: 1, w: 24, x: 0, y: 3 } },
  weeklyMrFailureRateStat,
  weeklyMrFailureRateBar,
  weeklyMasterFailureRateStat,
  weeklyMasterFailureRateBar,
  pipelineDurationRow { gridPos: { h: 1, w: 24, x: 0, y: 24 } },
  weeklyMrDurationStat,
  weeklyMrDurationBar,
  weeklyMrDurationPerTierStat,
  weeklyMrDurationPerTierBar,
  weeklyMasterDurationStat,
  weeklyMasterDurationBar,
  testCostsRow { gridPos: { h: 1, w: 24, x: 0, y: 55 } },
  testCostsCalculationText,
  weeklyMrTestCostStat,
  weeklyMrTestCostBar,
  weeklyMrTestCostPerTierStat,
  weeklyMrTestCostPerTierBar,
  weeklyMasterTestCostStat,
  weeklyMasterTestCostBar,
])
.trailer()
