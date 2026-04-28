local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local sql = import './common/sql.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';

local datasource = config.datasource;
local datasourceUid = config.datasourceUid;

// About text panel
local aboutTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 5, w: 24, x: 0, y: 0 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      ### Coverage Infrastructure

      Analyze test type distribution and CI job coverage contributions.

      - **Test Type Distribution**: Unit vs Integration test coverage balance
      - **Coverage by Job**: Which CI jobs contribute most to coverage
      - **Source Type Trends**: Coverage trends by test technology (RSpec, Jest, etc.)
    |||,
    mode: 'markdown',
  },
  title: '',
  type: 'text',
};

// Unit Test Only stat
local unitTestOnlyStat = {
  stableId: 'unit-test-only',
  datasource: panels.clickHouseDatasource,
  description: 'Source files covered only by unit tests (spec/models, spec/controllers, etc.) with no integration test coverage.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'blue', value: 0 }],
      },
      unit: 'locale',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 0, y: 5 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'auto',
    percentChangeColorMode: 'standard',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    showPercentChange: false,
    textMode: 'value',
    wideLayout: true,
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT COUNT(DISTINCT cm.file) AS "Unit Test Only"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.is_responsible = true
        AND cm.is_dependent = false
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Unit Test Only',
  type: 'stat',
};

// Integration Only stat
local integrationOnlyStat = {
  stableId: 'integration-only',
  datasource: panels.clickHouseDatasource,
  description: 'Source files covered only by integration/E2E tests (spec/requests, spec/features, etc.) with no dedicated unit tests.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'orange', value: 0 }],
      },
      unit: 'locale',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 8, y: 5 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'auto',
    percentChangeColorMode: 'standard',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    showPercentChange: false,
    textMode: 'value',
    wideLayout: true,
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT COUNT(DISTINCT cm.file) AS "Integration Only"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.is_responsible = false
        AND cm.is_dependent = true
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Integration Only',
  type: 'stat',
};

// Both Coverage Types stat
local bothCoverageTypesStat = {
  stableId: 'both-coverage-types',
  datasource: panels.clickHouseDatasource,
  description: 'Source files covered by both unit tests AND integration tests. These have the most robust test coverage.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
      unit: 'locale',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 16, y: 5 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'auto',
    percentChangeColorMode: 'standard',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    showPercentChange: false,
    textMode: 'value',
    wideLayout: true,
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT COUNT(DISTINCT cm.file) AS "Both Coverage Types"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.is_responsible = true
        AND cm.is_dependent = true
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Both Coverage Types',
  type: 'stat',
};

// Coverage by Job bar gauge
local coverageByJobBarGauge = {
  stableId: 'coverage-by-job-bar-gauge',
  datasource: panels.clickHouseDatasource,
  description: 'Average line coverage by CI job name. Shows which test suites contribute most coverage.',
  fieldConfig: {
    defaults: {
      color: { mode: 'palette-classic' },
      mappings: [],
      max: 100,
      min: 0,
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 3, w: 24, x: 0, y: 9 },
  options: {
    displayMode: 'basic',
    legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: false },
    maxVizHeight: 300,
    minVizHeight: 16,
    minVizWidth: 8,
    namePlacement: 'auto',
    orientation: 'horizontal',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: true },
    showUnfilled: true,
    sizing: 'auto',
    valueMode: 'color',
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT
          cm.ci_job_name AS "Job",
          ROUND(AVG(cm.line_coverage), 2) AS "Avg Line Coverage"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.ci_job_name != ''
        AND %s
      GROUP BY cm.ci_job_name
      ORDER BY "Avg Line Coverage" DESC
      LIMIT 15
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Coverage by Job',
  type: 'bargauge',
};

// Source Type Coverage Trends timeseries
local sourceTypeCoverageTrends = {
  datasource: panels.clickHouseDatasource,
  description: 'Line coverage over time by source type.',
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
      displayName: '${__field.labels.source_file_type}',
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
  gridPos: { h: 7, w: 24, x: 0, y: 12 },
  options: {
    legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
    tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    meta: { builderOptions: { columns: [], database: '', limit: 1000, mode: 'list', queryType: 'table', table: '' } },
    pluginVersion: '4.11.2',
    queryType: 'table',
    rawSql: |||
      SELECT
          cm.timestamp AS time,
          ROUND(AVG(cm.line_coverage), 2) AS value,
          cm.source_file_type
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE cm.line_coverage IS NOT NULL
        AND %s
        AND %s
      GROUP BY cm.timestamp, cm.source_file_type
      ORDER BY time ASC
    ||| % [sql.timeRangeFilter('timestamp'), sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Source Type Coverage Trends',
  transformations: [{ id: 'prepareTimeSeries', options: { format: 'multi' } }],
  type: 'timeseries',
};

config.addStandardTemplates(
  basic.dashboard(
    'Coverage Infrastructure',
    tags=config.codeCoverageTags,
    time_from='now-7d',
    time_to='now',
  )
  .addLink(config.backToHealthCheckLink)
)
.addPanels([
  aboutTextPanel,
  unitTestOnlyStat,
  integrationOnlyStat,
  bothCoverageTypesStat,
  coverageByJobBarGauge,
  sourceTypeCoverageTrends,
])
+ {
  editable: false,
  templating+: {
    list: std.filter(
      function(t) t.name != 'PROMETHEUS_DS' && t.name != 'environment',
      super.list
    ),
  },
}
