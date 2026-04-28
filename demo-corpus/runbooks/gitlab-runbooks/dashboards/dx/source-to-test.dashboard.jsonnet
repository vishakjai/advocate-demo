local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local sql = import './common/sql.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local template = grafana.template;

local datasource = config.datasource;
local datasourceUid = config.datasourceUid;

// ============================================================================
// Dashboard-specific helpers (used only in this dashboard)
// ============================================================================

// Threshold presets
local passRateThresholds = {
  mode: 'absolute',
  steps: [
    { color: 'red', value: 0 },
    { color: 'yellow', value: 80 },
    { color: 'green', value: 95 },
  ],
};

local retryRateThresholds = {
  mode: 'absolute',
  steps: [
    { color: 'green', value: 0 },
    { color: 'yellow', value: 5 },
    { color: 'red', value: 15 },
  ],
};

local testDurationThresholds = {
  mode: 'absolute',
  steps: [
    { color: 'green', value: 0 },
    { color: 'yellow', value: 30 },
    { color: 'red', value: 60 },
  ],
};

// Column overrides
local passPercentOverride(columnWidth=80) = {
  matcher: { id: 'byName', options: 'Pass %' },
  properties: [
    { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
    { id: 'thresholds', value: passRateThresholds },
    { id: 'unit', value: 'percent' },
    { id: 'custom.width', value: columnWidth },
  ],
};

local retryPercentOverride(columnWidth=80) = {
  matcher: { id: 'byName', options: 'Retry %' },
  properties: [
    { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
    { id: 'thresholds', value: retryRateThresholds },
    { id: 'unit', value: 'percent' },
    { id: 'custom.width', value: columnWidth },
  ],
};

local avgTimeOverride(columnWidth=100, columnName='Avg Time (s)') = {
  matcher: { id: 'byName', options: columnName },
  properties: [
    { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
    { id: 'thresholds', value: testDurationThresholds },
    { id: 'unit', value: 's' },
    { id: 'custom.width', value: columnWidth },
  ],
};

// SQL helpers
local testTypeClassificationCase(fileField) = |||
  CASE
    WHEN %s LIKE 'spec/%%' THEN 'RSpec'
    WHEN %s LIKE 'ee/spec/%%' THEN 'RSpec (EE)'
    WHEN %s LIKE 'qa/%%' THEN 'E2E'
    WHEN %s LIKE '%%_spec.js' OR %s LIKE '%%_spec.vue' THEN 'Jest'
    ELSE 'Other'
  END
||| % [fileField, fileField, fileField, fileField, fileField];

// Template variable for source file selection
local sourceFileTemplate = template.new(
  'source_file',
  datasource,
  |||
    SELECT '-- Select a source file --' AS file
    UNION ALL
    SELECT DISTINCT file
    FROM "code_coverage"."coverage_metrics"
    WHERE %s
    ORDER BY file ASC
  ||| % [sql.ciProjectPathFilter],
  label='Source File',
  refresh='load',
  includeAll=false,
);

// Stat panel for Tests Touching File
local testsTouchingFileStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Number of tests that touch (execute code in) the selected source file',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'red', value: 0 },
          { color: 'yellow', value: 5 },
          { color: 'green', value: 20 },
        ],
      },
      unit: 'none',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 0, y: 2 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'auto',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    showPercentChange: false,
    textMode: 'value',
    wideLayout: true,
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql:
      'SELECT COUNT(DISTINCT ' + sql.normalizeTestFilePath('m.test_file') + ') AS "Tests Touching File"\n' +
      'FROM ' + sql.testFileMappingsTable + ' m\n' +
      'INNER JOIN (\n' +
      '    SELECT file, line_coverage\n' +
      '    FROM ' + sql.coverageMetricsTable + '\n' +
      '    WHERE ' + sql.ciProjectPathFilter + '\n' +
      '      AND (source_file_type, timestamp) IN (' + sql.latestCoverageMetricsSubquery + ')\n' +
      ') c ON ' + sql.normalizeSourceFilePath('m.source_file') + ' = c.file\n' +
      'WHERE m.' + sql.ciProjectPathFilter + '\n' +
      '  AND ' + sql.normalizeSourceFilePath('m.source_file') + " LIKE concat('%', ${source_file:singlequote}, '%')\n" +
      '  AND c.line_coverage > 0',
    refId: 'A',
  }],
  title: 'Tests Touching File',
  type: 'stat',
};

// Stat panel for Line Coverage
local lineCoverageStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Current line coverage for the selected source file',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'red', value: 0 },
          { color: 'yellow', value: 50 },
          { color: 'green', value: 80 },
        ],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 8, y: 2 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'auto',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    showPercentChange: false,
    textMode: 'value',
    wideLayout: true,
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql:
      'SELECT ROUND(COALESCE(MAX(line_coverage), 0), 1) AS "Line Coverage"\n' +
      'FROM ' + sql.coverageMetricsTable + '\n' +
      'WHERE ' + sql.ciProjectPathFilter + '\n' +
      "  AND file LIKE concat('%', ${source_file:singlequote}, '%')\n" +
      '  AND (source_file_type, timestamp) IN (' + sql.latestCoverageMetricsSubquery + ')',
    refId: 'A',
  }],
  title: 'Line Coverage',
  type: 'stat',
};

// Stat panel for Branch Coverage
local branchCoverageStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Current branch coverage for the selected source file',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'red', value: 0 },
          { color: 'yellow', value: 50 },
          { color: 'green', value: 80 },
        ],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 16, y: 2 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'auto',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    showPercentChange: false,
    textMode: 'value',
    wideLayout: true,
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql:
      'SELECT ROUND(COALESCE(MAX(branch_coverage), 0), 1) AS "Branch Coverage"\n' +
      'FROM ' + sql.coverageMetricsTable + '\n' +
      'WHERE ' + sql.ciProjectPathFilter + '\n' +
      "  AND file LIKE concat('%', ${source_file:singlequote}, '%')\n" +
      '  AND (source_file_type, timestamp) IN (' + sql.latestCoverageMetricsSubquery + ')',
    refId: 'A',
  }],
  title: 'Branch Coverage',
  type: 'stat',
};

// About text panel
local aboutTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 5, w: 24, x: 0, y: 1 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      ### Source to Test Lookup

      Select a source file from the dropdown to see:
      - **Overview Stats** - Quick metrics including number of tests touching this file, line coverage %, and branch coverage %
      - **Tests Touching File** - Which tests execute code in this source file, with test health metrics (Pass %, Retry %, Avg Time) for the selected time range
      - **Test Types** - Whether coverage comes from RSpec, Jest, or E2E tests

      Use this to find relevant tests when modifying code or debugging failures.
    |||,
    mode: 'markdown',
  },
  title: '',
  type: 'text',
};

// Tests touching source file table
local testsTouchingTable = {
  datasource: panels.clickHouseDatasource,
  description: 'Tests that touch the selected source file',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      custom: {
        align: 'auto',
        cellOptions: { type: 'auto' },
        footer: { reducers: ['countAll'] },
        inspect: false,
      },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
    },
    overrides: [
      {
        matcher: { id: 'byName', options: 'Test File' },
        properties: [
          { id: 'custom.width', value: 450 },
          {
            id: 'links',
            value: [{
              title: 'See source files touched by this test',
              url: '/d/dx-test-to-source/dx-test-to-source?var-test_file=${__value.raw}',
            }],
          },
        ],
      },
      passPercentOverride(80),
      retryPercentOverride(80),
      avgTimeOverride(100),
    ],
  },
  gridPos: { h: 14, w: 24, x: 0, y: 7 },
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
    sortBy: [{ desc: false, displayName: 'Test File' }],
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql:
      'SELECT\n' +
      '    m.normalized_file AS "Test File",\n' +
      '    (' + testTypeClassificationCase('m.normalized_file') + ') AS "Test Type",\n' +
      '    ROUND(h.pass_rate, 1) AS "Pass %",\n' +
      '    ROUND(h.retry_rate, 1) AS "Retry %",\n' +
      '    ROUND(f.avg_duration / 1000, 2) AS "Avg Time (s)"\n' +
      'FROM (\n' +
      '    SELECT ' + sql.normalizeTestFilePath('test_file') + ' AS normalized_file\n' +
      '    FROM ' + sql.testFileMappingsTable + '\n' +
      '    PREWHERE ' + sql.ciProjectPathFilter + '\n' +
      '      AND ' + sql.normalizeSourceFilePath('source_file') + " LIKE concat('%', ${source_file:singlequote}, '%')\n" +
      '    GROUP BY normalized_file\n' +
      ') m\n' +
      'LEFT JOIN (\n' +
      '    SELECT\n' +
      '        test_file,\n' +
      '        sum(passed_runs) * 100.0 / nullIf(sum(total_runs), 0) AS pass_rate,\n' +
      '        sum(retried_runs) * 100.0 / nullIf(sum(total_runs), 0) AS retry_rate\n' +
      '    FROM test_metrics.test_health_daily\n' +
      '    WHERE date >= $__fromTime AND date <= $__toTime\n' +
      '    GROUP BY test_file\n' +
      ') h ON m.normalized_file = h.test_file\n' +
      'LEFT JOIN (\n' +
      '    SELECT\n' +
      '        file_path,\n' +
      '        avgMerge(avg_duration) AS avg_duration\n' +
      '    FROM test_metrics.test_flake_rates_daily\n' +
      '    WHERE date >= $__fromTime AND date <= $__toTime\n' +
      '    GROUP BY file_path\n' +
      ') f ON m.normalized_file = f.file_path\n' +
      'ORDER BY m.normalized_file',
    refId: 'A',
  }],
  title: 'Tests Touching This Source File',
  type: 'table',
};

// Coverage over time timeseries
local coverageOverTimePanel = {
  datasource: panels.clickHouseDatasource,
  description: 'Line and branch coverage for this source file over time',
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
        fillOpacity: 10,
        gradientMode: 'none',
        hideFrom: { legend: false, tooltip: false, viz: false },
        insertNulls: false,
        lineInterpolation: 'smooth',
        lineWidth: 2,
        pointSize: 5,
        scaleDistribution: { type: 'linear' },
        showPoints: 'auto',
        spanNulls: false,
        stacking: { group: 'A', mode: 'none' },
        thresholdsStyle: { mode: 'off' },
      },
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
  gridPos: { h: 8, w: 24, x: 0, y: 36 },
  options: {
    legend: {
      calcs: ['last', 'min', 'max'],
      displayMode: 'table',
      placement: 'bottom',
      showLegend: true,
    },
    tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
  },
  targets: [{
    editorType: 'sql',
    format: 0,
    queryType: 'timeseries',
    rawSql:
      'SELECT\n' +
      '    toStartOfDay(timestamp) AS time,\n' +
      '    ROUND(MAX(line_coverage), 1) AS "Line Coverage",\n' +
      '    ROUND(MAX(branch_coverage), 1) AS "Branch Coverage"\n' +
      'FROM "code_coverage"."coverage_metrics"\n' +
      'WHERE ' + sql.ciProjectPathFilter + '\n' +
      "  AND file LIKE concat('%', ${source_file:singlequote}, '%')\n" +
      '  AND timestamp >= $__fromTime\n' +
      '  AND timestamp <= $__toTime\n' +
      'GROUP BY time\n' +
      'ORDER BY time',
    refId: 'A',
  }],
  title: 'Coverage Over Time',
  type: 'timeseries',
};

// Build the dashboard
basic.dashboard(
  'Source to Test Coverage',
  tags=config.codeCoverageTags,
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=datasource,
)
.addTemplate(sourceFileTemplate)
.addLink(grafana.link.dashboards(
  'Test → Source',
  '',
  type='link',
  url='/d/dx-test-to-source/dx-test-to-source',
  icon='external link',
  keepTime=false,
  includeVars=false,
))
.addLink(grafana.link.dashboards(
  '← Health Check',
  '',
  type='link',
  url='/d/dx-code-coverage-health-check/dx-code-coverage-health-check',
  icon='arrow-left',
  keepTime=true,
  includeVars=false,
))
.addPanels([
  // About row (collapsed)
  grafana.row.new(title='About This Dashboard', collapse=true)
  + { gridPos: { h: 1, w: 24, x: 0, y: 0 } }
  + { panels: [aboutTextPanel] },

  // Overview row
  grafana.row.new(title='Overview', collapse=false)
  + { gridPos: { h: 1, w: 24, x: 0, y: 1 } },

  // Stat panels
  testsTouchingFileStat,
  lineCoverageStat,
  branchCoverageStat,

  // Tests touching source file row (collapsed)
  grafana.row.new(title='Tests Touching Source File', collapse=true)
  + { gridPos: { h: 1, w: 24, x: 0, y: 6 } }
  + { panels: [testsTouchingTable] },

  // Coverage trend row (collapsed)
  grafana.row.new(title='Coverage Trend', collapse=true)
  + { gridPos: { h: 1, w: 24, x: 0, y: 7 } }
  + { panels: [coverageOverTimePanel] },
])
+ {
  time: { from: 'now-6h', to: 'now' },
  editable: false,
  links+: [],
  // Filter out unused template variables
  templating+: {
    list: std.filter(
      function(t) t.name != 'PROMETHEUS_DS' && t.name != 'environment',
      super.list
    ),
  },
}
