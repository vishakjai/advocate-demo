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

local testCountThresholds = {
  mode: 'absolute',
  steps: [
    { color: 'red', value: 0 },
    { color: 'yellow', value: 6 },
    { color: 'green', value: 20 },
  ],
};

// Column overrides
local testCountOverride(columnWidth=80) = {
  matcher: { id: 'byName', options: '# Tests' },
  properties: [
    { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
    { id: 'thresholds', value: testCountThresholds },
    { id: 'custom.width', value: columnWidth },
  ],
};

// Template variable for test file selection
local testFileTemplate = template.new(
  'test_file',
  datasource,
  |||
    SELECT '-- Select a test file --' AS test_file
    UNION ALL
    SELECT %s AS test_file
    FROM %s
    PREWHERE %s
    GROUP BY test_file
    ORDER BY test_file ASC
  ||| % [sql.normalizeTestFilePath('test_file'), sql.testFileMappingsTable, sql.ciProjectPathFilter],
  label='Test File',
  refresh='load',
  includeAll=false,
);

// About text panel
local aboutTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 5, w: 24, x: 0, y: 1 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      ### Test to Source File Lookup

      Select a test file from the dropdown to see:
      - **Overview Stats** - Quick metrics including source files touched, sole coverage files (only this test touches them), and high-risk files (touched by ≤5 tests)
      - **Test Health** - Pass rate, retry rate (proxy for flakiness), and average run time for the selected time range
      - **Source Files Touched** - Which source files are executed (partially or fully) when this test runs, with a **# Tests** column showing test redundancy (red = few tests, green = many tests)
      - **Quarantine Impact** - Which files would lose all coverage if this test is quarantined
      - **Coverage Trend** - How the test's coverage footprint has changed over time

      Use this to understand test scope and assess risk before quarantining flaky tests.
    |||,
    mode: 'markdown',
  },
  title: '',
  type: 'text',
};

// Stat panel: Source Files Touched
local sourceFilesTouchedStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Total number of source files touched (partially or fully) by the selected test',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'blue', value: 0 }],
      },
      unit: 'none',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 3, y: 2 },
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
    rawSql: |||
      SELECT COUNT(DISTINCT m.source_file) AS "Source Files Touched"
      FROM %s m
      INNER JOIN (
          SELECT file, line_coverage
          FROM %s
          WHERE %s
            AND (source_file_type, timestamp) IN (%s)
      ) c ON %s = c.file
      WHERE %s
        AND %s LIKE concat('%%', ${test_file:singlequote}, '%%')
        AND c.line_coverage > 0
    ||| % [
      sql.testFileMappingsTable,
      sql.coverageMetricsTable,
      sql.ciProjectPathFilter,
      sql.latestCoverageMetricsSubquery,
      sql.normalizeSourceFilePath('m.source_file'),
      'm.' + sql.ciProjectPathFilter,
      sql.normalizeTestFilePath('m.test_file'),
    ],
    refId: 'A',
  }],
  title: 'Source Files Touched',
  type: 'stat',
};

// Stat panel: Sole Coverage Files
local soleCoverageFilesStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Source files where this is the ONLY test providing coverage (would lose all coverage if quarantined)',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'green', value: 0 },
          { color: 'yellow', value: 1 },
          { color: 'red', value: 5 },
        ],
      },
      unit: 'none',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 9, y: 2 },
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
    rawSql: |||
      SELECT COALESCE(MAX(sole_coverage_files), 0) AS "Sole Coverage"
      FROM code_coverage.flaky_test_coverage_impact
      WHERE test_file LIKE concat('%%', ${test_file:singlequote}, '%%')
    |||,
    refId: 'A',
  }],
  title: 'Sole Coverage Files',
  type: 'stat',
};

// Stat panel: High-Risk Files
local highRiskFilesStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Source files covered by 5 or fewer tests total (higher risk when quarantining tests)',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'green', value: 0 },
          { color: 'yellow', value: 5 },
          { color: 'red', value: 10 },
        ],
      },
      unit: 'none',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 15, y: 2 },
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
    rawSql: |||
      SELECT COUNT(*) AS "High-Risk Files"
      FROM (
          SELECT %s AS source
          FROM %s m
          INNER JOIN "code_coverage"."coverage_metrics" c
            ON %s = c.file
            AND %s
            AND c.line_coverage > 0
          PREWHERE %s
            AND %s LIKE concat('%%', ${test_file:singlequote}, '%%')
          WHERE (c.source_file_type, c.timestamp) IN (%s)
          GROUP BY source
      ) ts
      INNER JOIN "code_coverage"."source_file_test_counts" tc
        ON ts.source = tc.source_file
        AND %s
      WHERE tc.test_count <= 5
    ||| % [
      sql.normalizeSourceFilePath('m.source_file'),
      sql.testFileMappingsTable,
      sql.normalizeSourceFilePath('m.source_file'),
      'c.' + sql.ciProjectPathFilter,
      'm.' + sql.ciProjectPathFilter,
      sql.normalizeTestFilePath('m.test_file'),
      sql.latestCoverageMetricsSubquery,
      'tc.' + sql.ciProjectPathFilter,
    ],
    refId: 'A',
  }],
  title: 'High-Risk Files',
  type: 'stat',
};

// Stat panel: Pass Rate
local passRateStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Percentage of test runs that passed in the selected time range',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: passRateThresholds,
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 0, y: 7 },
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
    rawSql: |||
      SELECT
        ROUND(sum(passed_runs) * 100.0 / nullIf(sum(total_runs), 0), 1) AS "Pass Rate"
      FROM test_metrics.test_health_daily
      WHERE test_file LIKE concat('%', ${test_file:singlequote}, '%')
        AND date >= $__fromTime AND date <= $__toTime
    |||,
    refId: 'A',
  }],
  title: 'Pass Rate',
  type: 'stat',
};

// Stat panel: Retry Rate
local retryRateStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Percentage of test runs that were retried (proxy for flakiness)',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: retryRateThresholds,
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 8, y: 7 },
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
    rawSql: |||
      SELECT
        ROUND(sum(retried_runs) * 100.0 / nullIf(sum(total_runs), 0), 1) AS "Retry Rate"
      FROM test_metrics.test_health_daily
      WHERE test_file LIKE concat('%', ${test_file:singlequote}, '%')
        AND date >= $__fromTime AND date <= $__toTime
    |||,
    refId: 'A',
  }],
  title: 'Retry Rate',
  type: 'stat',
};

// Stat panel: Avg Run Time
local avgRunTimeStat = {
  datasource: panels.clickHouseDatasource,
  description: 'Average test execution time in seconds',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: testDurationThresholds,
      unit: 's',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 8, x: 16, y: 7 },
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
    rawSql: |||
      SELECT
        ROUND(avgMerge(avg_duration) / 1000, 2) AS "Avg Run Time"
      FROM test_metrics.test_flake_rates_daily
      WHERE file_path LIKE concat('%', ${test_file:singlequote}, '%')
        AND date >= $__fromTime AND date <= $__toTime
    |||,
    refId: 'A',
  }],
  title: 'Avg Run Time',
  type: 'stat',
};

// Table: Source Files Touched
local sourceFilesTouchedTable = {
  datasource: panels.clickHouseDatasource,
  description: 'Source files touched by the selected test. The # Tests column shows how many tests touch each file (red = few tests, higher risk if quarantined; green = many tests, lower risk).',
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
        matcher: { id: 'byName', options: 'Source File' },
        properties: [
          { id: 'custom.width', value: 500 },
          {
            id: 'links',
            value: [{
              title: 'See tests covering this source file',
              url: '/d/dx-source-to-test/dx-source-to-test?var-source_file=${__value.raw}',
            }],
          },
        ],
      },
      testCountOverride(),
    ],
  },
  gridPos: { h: 12, w: 24, x: 0, y: 8 },
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
    sortBy: [{ desc: false, displayName: '# Tests' }],
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT
          src.normalized_source AS "Source File",
          src.categories AS "Categories",
          src.line_coverage AS "Line %%",
          src.branch_coverage AS "Branch %%",
          tc.test_count AS "# Tests"
      FROM (
          SELECT
              %s AS normalized_source,
              arrayStringConcat(groupUniqArray(c.category), ', ') AS categories,
              ROUND(MAX(c.line_coverage), 1) AS line_coverage,
              ROUND(MAX(c.branch_coverage), 1) AS branch_coverage
          FROM %s m
          INNER JOIN "code_coverage"."coverage_metrics" c
            ON %s = c.file
            AND %s
          WHERE %s
            AND %s LIKE concat('%%', ${test_file:singlequote}, '%%')
            AND c.line_coverage > 0
            AND (c.source_file_type, c.timestamp) IN (%s)
          GROUP BY normalized_source
      ) src
      LEFT JOIN "code_coverage"."source_file_test_counts" tc
        ON src.normalized_source = tc.source_file
        AND %s
      ORDER BY tc.test_count ASC, src.normalized_source
    ||| % [
      sql.normalizeSourceFilePath('m.source_file'),
      sql.testFileMappingsTable,
      sql.normalizeSourceFilePath('m.source_file'),
      'c.' + sql.ciProjectPathFilter,
      'm.' + sql.ciProjectPathFilter,
      sql.normalizeTestFilePath('m.test_file'),
      sql.latestCoverageMetricsSubquery,
      'tc.' + sql.ciProjectPathFilter,
    ],
    refId: 'A',
  }],
  title: 'Source Files Touched',
  type: 'table',
};

// Table: Quarantine Impact
local quarantineImpactTable = {
  datasource: panels.clickHouseDatasource,
  description: 'Source files that would lose all test coverage if the selected test is quarantined',
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
        steps: [{ color: 'red', value: 0 }],
      },
    },
    overrides: [
      {
        matcher: { id: 'byName', options: 'Source File' },
        properties: [
          { id: 'custom.width', value: 500 },
          {
            id: 'links',
            value: [{
              title: 'See tests covering this source file',
              url: '/d/dx-source-to-test/dx-source-to-test?var-source_file=${__value.raw}',
            }],
          },
        ],
      },
      {
        matcher: { id: 'byName', options: 'Line %' },
        properties: [
          { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
          {
            id: 'thresholds',
            value: {
              mode: 'absolute',
              steps: [
                { color: 'red', value: 0 },
                { color: 'yellow', value: 50 },
                { color: 'green', value: 80 },
              ],
            },
          },
        ],
      },
    ],
  },
  gridPos: { h: 10, w: 24, x: 0, y: 9 },
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
    sortBy: [],
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT
          src.normalized_source AS "Source File",
          src.categories AS "Categories",
          src.line_coverage AS "Line %%"
      FROM (
          SELECT
              %s AS normalized_source,
              arrayStringConcat(groupUniqArray(c.category), ', ') AS categories,
              ROUND(MAX(c.line_coverage), 1) AS line_coverage
          FROM %s m
          INNER JOIN "code_coverage"."coverage_metrics" c
            ON %s = c.file
            AND %s
          WHERE %s
            AND %s LIKE concat('%%', ${test_file:singlequote}, '%%')
            AND c.line_coverage > 0
            AND (c.source_file_type, c.timestamp) IN (%s)
          GROUP BY normalized_source
      ) src
      INNER JOIN "code_coverage"."source_file_test_counts" tc
        ON src.normalized_source = tc.source_file
        AND %s
      WHERE tc.test_count = 1
      ORDER BY src.line_coverage DESC
    ||| % [
      sql.normalizeSourceFilePath('m.source_file'),
      sql.testFileMappingsTable,
      sql.normalizeSourceFilePath('m.source_file'),
      'c.' + sql.ciProjectPathFilter,
      'm.' + sql.ciProjectPathFilter,
      sql.normalizeTestFilePath('m.test_file'),
      sql.latestCoverageMetricsSubquery,
      'tc.' + sql.ciProjectPathFilter,
    ],
    refId: 'A',
  }],
  title: 'Source Files That Would Lose All Coverage',
  type: 'table',
};

// Timeseries: Coverage Trend
local coverageTrendPanel = {
  datasource: panels.clickHouseDatasource,
  description: 'Number of source files touched by this test over time',
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
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
      unit: 'none',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 24, x: 0, y: 10 },
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
    rawSql: |||
      SELECT
          toStartOfDay(m.timestamp) AS time,
          COUNT(DISTINCT %s) AS "Source Files Touched"
      FROM %s m
      WHERE %s
        AND %s LIKE concat('%%', ${test_file:singlequote}, '%%')
        AND m.timestamp >= $__fromTime
        AND m.timestamp <= $__toTime
      GROUP BY time
      ORDER BY time
    ||| % [
      sql.normalizeSourceFilePath('m.source_file'),
      sql.testFileMappingsTable,
      'm.' + sql.ciProjectPathFilter,
      sql.normalizeTestFilePath('m.test_file'),
    ],
    refId: 'A',
  }],
  title: 'Source Files Touched Over Time',
  type: 'timeseries',
};

// Build the dashboard
basic.dashboard(
  'Test to Source File Coverage',
  tags=config.codeCoverageTags,
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=datasource,
  time_from='now-7d',
  time_to='now',
)
.addTemplate(testFileTemplate)
.addLink(grafana.link.dashboards(
  'Source → Test',
  '',
  type='link',
  url='/d/dx-source-to-test/dx-source-to-test',
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

  // Overview stat panels
  sourceFilesTouchedStat,
  soleCoverageFilesStat,
  highRiskFilesStat,

  // Test Health row (collapsed)
  grafana.row.new(title='Test Health', collapse=true)
  + { gridPos: { h: 1, w: 24, x: 0, y: 6 } }
  + { panels: [passRateStat, retryRateStat, avgRunTimeStat] },

  // Source Files Touched row (collapsed)
  grafana.row.new(title='Source Files Touched by Test', collapse=true)
  + { gridPos: { h: 1, w: 24, x: 0, y: 7 } }
  + { panels: [sourceFilesTouchedTable] },

  // Quarantine Impact row (collapsed)
  grafana.row.new(title='Quarantine Impact Analysis', collapse=true)
  + { gridPos: { h: 1, w: 24, x: 0, y: 8 } }
  + { panels: [quarantineImpactTable] },

  // Coverage Trend row (collapsed)
  grafana.row.new(title='Coverage Trend', collapse=true)
  + { gridPos: { h: 1, w: 24, x: 0, y: 9 } }
  + { panels: [coverageTrendPanel] },
])
+ {
  time: { from: 'now-7d', to: 'now' },
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
