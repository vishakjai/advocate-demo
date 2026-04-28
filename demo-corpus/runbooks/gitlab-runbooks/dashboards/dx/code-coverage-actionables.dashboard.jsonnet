local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local sql = import './common/sql.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';

local datasource = config.datasource;
local datasourceUid = config.datasourceUid;

// ============================================================================
// Dashboard-specific helpers (used only in this dashboard)
// ============================================================================

// SQL CTEs
local testFlakyStatsCte = std.join('\n', [
  'test_flaky_stats AS (',
  '  SELECT test_file, total_cases, flaky_cases',
  '  FROM (',
  '    SELECT',
  '      test_file,',
  '      uniqMerge(total_cases) AS total_cases,',
  '      uniqIfMerge(flaky_cases) AS flaky_cases',
  '    FROM test_metrics.test_file_flaky_summary',
  '    WHERE ' + sql.timeRangeFilter('date'),
  '    GROUP BY test_file',
  '  )',
  '  WHERE flaky_cases > 0',
  ')',
]);

// SQL case expressions
// Risk level filter must match gitlab-org/quality/triage-ops.
local riskLevelCaseFromCounts(testCount, fullyCount, partiallyCount) =
  'CASE\n' +
  '            WHEN ' + testCount + ' <= ' + fullyCount + " THEN 'CRITICAL'\n" +
  '            WHEN ' + testCount + ' <= ' + fullyCount + ' + ' + partiallyCount + " THEN 'HIGH'\n" +
  '            WHEN ' + fullyCount + " > 0 THEN 'MEDIUM'\n" +
  "            ELSE 'LOW'\n" +
  '        END';

// Complete SQL queries
local quarantineRiskSql = std.join('\n', [
  'WITH test_quarantine_stats AS (',
  '    SELECT test_file, total_cases, quarantined_cases',
  '    FROM (',
  '        SELECT',
  '            test_file,',
  '            uniqMerge(total_cases) AS total_cases,',
  '            uniqIfMerge(quarantined_cases) AS quarantined_cases',
  '        FROM test_metrics.test_file_quarantine_summary',
  '        WHERE ' + sql.timeRangeFilter('date'),
  '        GROUP BY test_file',
  '    )',
  '    WHERE quarantined_cases > 0',
  '),',
  'source_test_pairs AS (',
  '    SELECT',
  "        replaceOne(tfm.source_file, './', '') AS src_file,",
  '        tqs.test_file AS tst_file,',
  '        tqs.total_cases AS tot_cases,',
  '        tqs.quarantined_cases AS q_cases',
  '    FROM ' + sql.testFileMappingsTable + ' tfm',
  "    INNER JOIN test_quarantine_stats tqs ON replaceRegexpOne(tfm.test_file, ':\\d+, ', '') = tqs.test_file",
  "    PREWHERE tfm.ci_project_path = 'gitlab-org/gitlab'",
  "      AND (${section:singlequote} = 'All' OR tfm.section IN (${section:singlequote}))",
  "      AND (${stage:singlequote} = 'All' OR tfm.stage IN (${stage:singlequote}))",
  "      AND (${group:singlequote} = 'All' OR tfm.`group` IN (${group:singlequote}))",
  "      AND (${category:singlequote} = 'All' OR tfm.category IN (${category:singlequote}))",
  '    GROUP BY src_file, tst_file, tot_cases, q_cases',
  '),',
  'quarantine_agg AS (',
  '    SELECT',
  '        src_file,',
  '        countIf(q_cases >= tot_cases) AS fully_quarantined,',
  '        countIf(q_cases < tot_cases) AS partially_quarantined,',
  "        arrayStringConcat(groupArray(CONCAT(tst_file, ' (', toString(ROUND(q_cases * 100 / tot_cases)), '%%)')), ', ') AS quarantined_tests",
  '    FROM source_test_pairs',
  '    GROUP BY src_file',
  ')',
  'SELECT',
  '    q.src_file AS "Source File",',
  '    CASE',
  "        WHEN tc.test_count <= q.fully_quarantined THEN 'CRITICAL'",
  "        WHEN tc.test_count <= q.fully_quarantined + q.partially_quarantined THEN 'HIGH'",
  "        WHEN q.fully_quarantined > 0 THEN 'MEDIUM'",
  "        ELSE 'LOW'",
  '    END AS "Risk Level",',
  '    tc.test_count AS "Total Tests",',
  '    q.fully_quarantined AS "Fully Quarantined",',
  '    q.partially_quarantined AS "Partially Quarantined",',
  '    ROUND(cm.line_coverage, 1) AS "Line %",',
  '    q.quarantined_tests AS "Quarantined Tests"',
  'FROM quarantine_agg q',
  'INNER JOIN (',
  '    SELECT',
  "        replaceOne(source_file, './', '') AS source_file,",
  '        COUNT(DISTINCT test_file) AS test_count',
  '    FROM ' + sql.testFileMappingsTable,
  "    WHERE ci_project_path = 'gitlab-org/gitlab'",
  "      AND (${section:singlequote} = 'All' OR section IN (${section:singlequote}))",
  "      AND (${stage:singlequote} = 'All' OR stage IN (${stage:singlequote}))",
  "      AND (${group:singlequote} = 'All' OR `group` IN (${group:singlequote}))",
  "      AND (${category:singlequote} = 'All' OR category IN (${category:singlequote}))",
  '    GROUP BY source_file',
  ') tc ON q.src_file = tc.source_file',
  'LEFT JOIN (',
  '    SELECT file, line_coverage, category',
  '    FROM ' + sql.coverageMetricsTable,
  "    WHERE ci_project_path = 'gitlab-org/gitlab'",
  '      AND (source_file_type, timestamp) IN (',
  '          SELECT source_file_type, MAX(timestamp)',
  '          FROM ' + sql.coverageMetricsTable,
  "          WHERE ci_project_path = 'gitlab-org/gitlab'",
  '          GROUP BY source_file_type',
  '      )',
  ') cm ON q.src_file = cm.file',
  'LEFT JOIN code_coverage.category_owners co ON cm.category = co.category',
  'ORDER BY',
  '    CASE WHEN tc.test_count <= q.fully_quarantined THEN 1',
  '         WHEN tc.test_count <= q.fully_quarantined + q.partially_quarantined THEN 2',
  '         WHEN q.fully_quarantined > 0 THEN 3',
  '         ELSE 4 END,',
  '    q.fully_quarantined DESC,',
  '    cm.line_coverage DESC',
  'LIMIT 50',
]);

// Panel factory functions and overrides
local sourceFileLinkOverride(columnWidth=300) = {
  matcher: { id: 'byName', options: 'Source File' },
  properties: [
    { id: 'custom.width', value: columnWidth },
    {
      id: 'links',
      value: [{
        title: 'View in Source to Test Lookup',
        url: '/d/source-to-test/source-to-test-coverage?var-source_file=${__value.raw}',
      }],
    },
  ],
};

local linePercentOverride(columnWidth=70) = {
  matcher: { id: 'byName', options: 'Line %' },
  properties: [
    { id: 'unit', value: 'percent' },
    { id: 'custom.width', value: columnWidth },
  ],
};

local totalTestsOverride(columnWidth=89) = {
  matcher: { id: 'byName', options: 'Total Tests' },
  properties: [
    { id: 'custom.width', value: columnWidth },
  ],
};

local quarantineRiskTable(datasourceUid, gridPos, rawSql) = {
  datasource: { type: 'grafana-clickhouse-datasource', uid: datasourceUid },
  description: 'Click Source File to see which tests cover it.',
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
        steps: [{ color: 'green', value: 0 }],
      },
    },
    overrides: [
      sourceFileLinkOverride(),
      linePercentOverride(),
      {
        matcher: { id: 'byName', options: 'Fully Quarantined' },
        properties: [{ id: 'custom.width', value: 120 }],
      },
      {
        matcher: { id: 'byName', options: 'Partially Quarantined' },
        properties: [{ id: 'custom.width', value: 140 }],
      },
      panels.riskLevelOverride(),
      totalTestsOverride(),
    ],
  },
  gridPos: gridPos,
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
    sortBy: [],
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: rawSql,
    refId: 'A',
  }],
  title: 'Quarantine Risk (Coverage from Quarantined Tests)',
  type: 'table',
};

local quarantineRiskLegendSourceFiles(gridPos) = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: gridPos,
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      **Risk Levels:**

      Shows the risk level for each source file based on its test coverage status.

      - <span style="color:#F2495C">**CRITICAL**</span> = ALL tests covering this file are fully quarantined
      - <span style="color:#FF9830">**HIGH**</span> = ALL tests covering this file are quarantined (fully or partially)
      - <span style="color:#FADE2A">**MEDIUM**</span> = Mix of quarantined and healthy tests
      - <span style="color:#73BF69">**LOW**</span> = Only partially quarantined tests

      Higher risk = file would lose all/most coverage if quarantined tests are removed.
    |||,
    mode: 'markdown',
  },
  pluginVersion: '12.3.1',
  title: '',
  transparent: true,
  type: 'text',
};

// About text panel
local aboutTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 7, w: 24, x: 0, y: 0 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      ### Coverage Actionables

      Find and fix coverage gaps in your codebase.

      **How to use:**
      - **Test Reliability Risk** - Coverage depending on quarantined or flaky tests
      - **Critical Coverage Gaps** - Files with low or imbalanced coverage
      - **Test Optimization** - Slow tests with low coverage ROI

      Use the filters above to focus on your team's files.
    |||,
    mode: 'markdown',
  },
  title: '',
  type: 'text',
};

// Row: Test Reliability Risk
local testReliabilityRiskRow = {
  stableId: 'test-reliability-risk-row',
  collapsed: false,
  gridPos: { h: 1, w: 24, x: 0, y: 7 },
  panels: [],
  title: 'Test Reliability Risk',
  type: 'row',
};

// Quarantine Risk table
local quarantineRiskTablePanel = quarantineRiskTable(
  datasourceUid,
  { h: 7, w: 18, x: 0, y: 8 },
  quarantineRiskSql
);

// Quarantine Risk legend
local quarantineRiskLegend = quarantineRiskLegendSourceFiles({ h: 7, w: 6, x: 18, y: 8 });

// Flaky Coverage SQL using parameterized risk level
local flakyCoverageSql = std.join('\n', [
  'WITH ' + testFlakyStatsCte + ',',
  'source_test_pairs AS (',
  '    SELECT',
  '        ' + sql.normalizeSourceFilePath('tfm.source_file') + ' AS src_file,',
  '        tfs.test_file AS tst_file,',
  '        tfs.total_cases AS tot_cases,',
  '        tfs.flaky_cases AS f_cases',
  '    FROM ' + sql.testFileMappingsTable + ' tfm',
  '    INNER JOIN test_flaky_stats tfs ON ' + sql.normalizeTestFilePath('tfm.test_file') + ' = tfs.test_file',
  '    PREWHERE tfm.' + sql.ciProjectPathFilter,
  "      AND (${section:singlequote} = 'All' OR tfm.section IN (${section:singlequote}))",
  "      AND (${stage:singlequote} = 'All' OR tfm.stage IN (${stage:singlequote}))",
  "      AND (${group:singlequote} = 'All' OR tfm.`group` IN (${group:singlequote}))",
  "      AND (${category:singlequote} = 'All' OR tfm.category IN (${category:singlequote}))",
  '    GROUP BY src_file, tst_file, tot_cases, f_cases',
  '),',
  'flaky_agg AS (',
  '    SELECT',
  '        src_file,',
  '        countIf(f_cases >= tot_cases) AS fully_flaky,',
  '        countIf(f_cases < tot_cases) AS partially_flaky,',
  "        arrayStringConcat(groupArray(CONCAT(tst_file, ' (', toString(ROUND(f_cases * 100 / tot_cases)), '%%)')), ', ') AS flaky_tests",
  '    FROM source_test_pairs',
  '    GROUP BY src_file',
  ')',
  'SELECT',
  '    f.src_file AS "Source File",',
  '    ' + riskLevelCaseFromCounts('tc.test_count', 'f.fully_flaky', 'f.partially_flaky') + ' AS "Risk Level",',
  '    tc.test_count AS "Total Tests",',
  '    f.fully_flaky AS "Fully Flaky",',
  '    f.partially_flaky AS "Partially Flaky",',
  '    ROUND(cm.line_coverage, 1) AS "Line %",',
  '    f.flaky_tests AS "Flaky Tests"',
  'FROM flaky_agg f',
  'INNER JOIN (',
  '    SELECT',
  '        ' + sql.normalizeSourceFilePath('source_file') + ' AS source_file,',
  '        COUNT(DISTINCT test_file) AS test_count',
  '    FROM ' + sql.testFileMappingsTable,
  '    WHERE ' + sql.ciProjectPathFilter,
  "      AND (${section:singlequote} = 'All' OR section IN (${section:singlequote}))",
  "      AND (${stage:singlequote} = 'All' OR stage IN (${stage:singlequote}))",
  "      AND (${group:singlequote} = 'All' OR `group` IN (${group:singlequote}))",
  "      AND (${category:singlequote} = 'All' OR category IN (${category:singlequote}))",
  '    GROUP BY source_file',
  ') tc ON f.src_file = tc.source_file',
  'LEFT JOIN (',
  '    SELECT file, line_coverage, category',
  '    FROM ' + sql.coverageMetricsTable,
  '    WHERE ' + sql.ciProjectPathFilter,
  '      AND (source_file_type, timestamp) IN (',
  '          SELECT source_file_type, MAX(timestamp)',
  '          FROM ' + sql.coverageMetricsTable,
  '          WHERE ' + sql.ciProjectPathFilter,
  '          GROUP BY source_file_type',
  '      )',
  ') cm ON f.src_file = cm.file',
  'LEFT JOIN code_coverage.category_owners co ON cm.category = co.category',
  'ORDER BY',
  '    CASE WHEN tc.test_count <= f.fully_flaky THEN 1',
  '         WHEN tc.test_count <= f.fully_flaky + f.partially_flaky THEN 2',
  '         WHEN f.fully_flaky > 0 THEN 3',
  '         ELSE 4 END,',
  '    f.fully_flaky DESC,',
  '    cm.line_coverage DESC',
  'LIMIT 50',
]);

// Flaky Coverage table
local flakyCoverageTable = {
  stableId: 'flaky-coverage-table',
  datasource: panels.clickHouseDatasource,
  description: 'Click Source File to see which tests cover it.',
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
        steps: [{ color: 'green', value: 0 }],
      },
    },
    overrides: [
      sourceFileLinkOverride(),
      linePercentOverride(),
      {
        matcher: { id: 'byName', options: 'Fully Flaky' },
        properties: [{ id: 'custom.width', value: 87 }],
      },
      {
        matcher: { id: 'byName', options: 'Partially Flaky' },
        properties: [{ id: 'custom.width', value: 109 }],
      },
      panels.riskLevelOverride(91),
      totalTestsOverride(87),
    ],
  },
  gridPos: { h: 7, w: 18, x: 0, y: 15 },
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
    sortBy: [],
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: flakyCoverageSql,
    refId: 'A',
  }],
  title: 'Flaky Coverage (Coverage from Retried Tests)',
  type: 'table',
};

// Flaky Risk legend
local flakyRiskLegend = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 7, w: 6, x: 18, y: 15 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      **Risk Levels:**
      - <span style="color:#F2495C">**CRITICAL**</span> = all tests fully flaky
      - <span style="color:#FF9830">**HIGH**</span> = all tests have some flakiness
      - <span style="color:#FADE2A">**MEDIUM**</span> = some fully flaky + stable
      - <span style="color:#73BF69">**LOW**</span> = only partially flaky
    |||,
    mode: 'markdown',
  },
  pluginVersion: '12.3.1',
  title: '',
  transparent: true,
  type: 'text',
};

// Row: Critical Coverage Gaps
local criticalCoverageGapsRow = {
  stableId: 'critical-coverage-gaps-row',
  collapsed: false,
  gridPos: { h: 1, w: 24, x: 0, y: 22 },
  panels: [],
  title: 'Critical Coverage Gaps',
  type: 'row',
};

// Critical Low Coverage Files table
local criticalLowCoverageTable = {
  stableId: 'critical-low-coverage-table',
  datasource: panels.clickHouseDatasource,
  description: 'Click File to see which tests cover it.',
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
          { color: 'transparent', value: 0 },
          { color: 'dark-green', value: 0.01 },
          { color: 'semi-dark-yellow', value: 5 },
          { color: 'semi-dark-orange', value: 8 },
        ],
      },
    },
    overrides: [
      {
        matcher: { id: 'byName', options: 'File' },
        properties: [
          { id: 'links', value: [{ title: 'View tests covering this file', url: '/d/source-to-test/source-to-test-coverage?var-source_file=${__value.text}&${__url_time_range}' }] },
          { id: 'custom.width', value: 554 },
        ],
      },
      {
        matcher: { id: 'byName', options: 'Category' },
        properties: [
          { id: 'links', value: [{ title: 'Filter by Category', url: '/d/${__dashboard.uid}/${__dashboard}?var-category=${__value.raw}' }] },
          { id: 'custom.width', value: 93 },
        ],
      },
      { matcher: { id: 'byName', options: 'Line %' }, properties: [{ id: 'custom.width', value: 71 }] },
      { matcher: { id: 'byName', options: 'Branch %' }, properties: [{ id: 'custom.width', value: 86 }] },
      { matcher: { id: 'byName', options: 'Function %' }, properties: [{ id: 'custom.width', value: 96 }] },
      { matcher: { id: 'byName', options: 'Source Type' }, properties: [{ id: 'custom.width', value: 114 }] },
    ],
  },
  gridPos: { h: 8, w: 24, x: 0, y: 23 },
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
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
          cm.file AS "File",
          cm.source_file_type AS "Source Type",
          CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END AS "Category",
          ROUND(cm.line_coverage, 2) AS "Line %%",
          ROUND(cm.branch_coverage, 2) AS "Branch %%",
          ROUND(cm.function_coverage, 2) AS "Function %%"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.line_coverage < 25
        AND %s
      ORDER BY cm.line_coverage ASC
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Critical Low Coverage Files',
  type: 'table',
};

// Line vs Branch Coverage Gap scatter plot
local lineBranchGapScatter = {
  stableId: 'line-branch-gap-scatter',
  datasource: panels.clickHouseDatasource,
  description: 'Hover over points to see file details.',
  fieldConfig: {
    defaults: {
      color: { mode: 'continuous-GrYlRd', seriesBy: 'last' },
      custom: {
        axisBorderShow: true,
        axisCenteredZero: false,
        axisColorMode: 'series',
        axisLabel: '',
        axisPlacement: 'auto',
        fillOpacity: 100,
        hideFrom: { legend: false, tooltip: false, viz: false },
        pointShape: 'circle',
        pointSize: { fixed: 5 },
        pointStrokeWidth: 3,
        scaleDistribution: { type: 'linear' },
        show: 'points',
      },
      fieldMinMax: false,
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 12, x: 0, y: 31 },
  options: {
    legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: false },
    mapping: 'auto',
    series: [{
      color: { matcher: { id: 'byName', options: 'Gap' } },
      x: { matcher: { id: 'byName', options: 'Line' } },
      y: { matcher: { id: 'byName', options: 'Branch' } },
    }],
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
          cm.file AS "File",
          ROUND(MAX(cm.line_coverage), 2) AS "Line",
          ROUND(MAX(cm.branch_coverage), 2) AS "Branch",
          ROUND(MAX(cm.line_coverage) - MAX(cm.branch_coverage), 2) AS "Gap"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.branch_coverage IS NOT NULL
        AND %s
      GROUP BY cm.file
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Line vs Branch Coverage Gap',
  type: 'xychart',
};

// Line vs Function Coverage Gap scatter plot
local lineFunctionGapScatter = {
  stableId: 'line-function-gap-scatter',
  datasource: panels.clickHouseDatasource,
  description: 'Hover over points to see file details.',
  fieldConfig: {
    defaults: {
      color: { mode: 'continuous-GrYlRd', seriesBy: 'last' },
      custom: {
        axisBorderShow: true,
        axisCenteredZero: false,
        axisColorMode: 'series',
        axisLabel: '',
        axisPlacement: 'auto',
        fillOpacity: 100,
        hideFrom: { legend: false, tooltip: false, viz: false },
        pointShape: 'circle',
        pointSize: { fixed: 5 },
        pointStrokeWidth: 3,
        scaleDistribution: { type: 'linear' },
        show: 'points',
      },
      fieldMinMax: false,
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 12, x: 12, y: 31 },
  options: {
    legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: false },
    mapping: 'auto',
    series: [{
      color: { matcher: { id: 'byName', options: 'Gap' } },
      frame: { matcher: { id: 'byIndex', options: 0 } },
      x: { matcher: { id: 'byName', options: 'Line' } },
      y: { matcher: { id: 'byName', options: 'Function' } },
    }],
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
          cm.file AS "File",
          ROUND(MAX(cm.line_coverage), 2) AS "Line",
          ROUND(MAX(cm.function_coverage), 2) AS "Function",
          ROUND(MAX(cm.line_coverage) - MAX(cm.function_coverage), 2) AS "Gap"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.function_coverage IS NOT NULL
        AND %s
      GROUP BY cm.file
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Line vs Function Coverage Gap',
  type: 'xychart',
};

// Coverage Gaps table
local coverageGapsTable = {
  stableId: 'coverage-gaps-table',
  datasource: panels.clickHouseDatasource,
  description: 'Click File to see which tests cover it.',
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
        matcher: { id: 'byName', options: 'File' },
        properties: [
          { id: 'custom.width', value: 220 },
          { id: 'links', value: [{ title: 'View tests covering this file', url: '/d/source-to-test/source-to-test-coverage?var-source_file=${__value.text}&${__url_time_range}' }] },
        ],
      },
    ],
  },
  gridPos: { h: 7, w: 19, x: 0, y: 39 },
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
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
          cm.file AS "File",
          ROUND(MAX(cm.line_coverage), 2) AS "Line %%",
          ROUND(MAX(cm.branch_coverage), 2) AS "Branch %%",
          ROUND(MAX(cm.function_coverage), 2) AS "Function %%",
          ROUND(MAX(cm.line_coverage) - MAX(cm.branch_coverage), 2) AS "Line-Branch Gap",
          ROUND(MAX(cm.line_coverage) - MAX(cm.function_coverage), 2) AS "Line-Function Gap"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.line_coverage >= 70
        AND (cm.branch_coverage < 50 OR cm.function_coverage < 50)
        AND %s
      GROUP BY cm.file
      ORDER BY "Line-Branch Gap" DESC
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Coverage Gaps',
  type: 'table',
};

// Coverage Gaps explanation
local coverageGapsExplanation = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 7, w: 5, x: 19, y: 39 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: 'Files with 70%+ line coverage but <50% branch or function. Tests run through code but skip edge cases.',
    mode: 'markdown',
  },
  pluginVersion: '12.3.1',
  title: '',
  transparent: true,
  type: 'text',
};

// Row: Test Optimization
local testOptimizationRow = {
  stableId: 'test-optimization-row',
  collapsed: false,
  gridPos: { h: 1, w: 24, x: 0, y: 46 },
  panels: [],
  title: 'Test Optimization',
  type: 'row',
};

// Slow Test ROI table
local slowTestRoiTable = {
  stableId: 'slow-test-roi-table',
  datasource: panels.clickHouseDatasource,
  description: 'Click Test File to see which source files it covers.',
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
        steps: [{ color: 'red', value: 0 }],
      },
    },
    overrides: [
      {
        matcher: { id: 'byName', options: 'Test File' },
        properties: [
          { id: 'links', value: [{ title: 'View in Test-to-Source Dashboard', url: '/d/test-to-source/test-to-source-file-coverage?var-test_file=${__value.raw}&${__url_time_range}' }] },
        ],
      },
      {
        matcher: { id: 'byName', options: 'Avg Runtime (s)' },
        properties: [{ id: 'custom.cellOptions', value: { type: 'color-background' } }],
      },
    ],
  },
  gridPos: { h: 8, w: 19, x: 0, y: 47 },
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: std.join('\n', [
      'WITH slow_tests AS (',
      '    SELECT',
      '        file_path,',
      '        ' + sql.normalizeTestFilePath('file_path') + ' AS normalized_path,',
      '        avgMerge(avg_duration) AS avg_runtime_ms',
      '    FROM test_metrics.test_flake_rates_daily',
      '    WHERE ' + sql.timeRangeFilter('date'),
      '    GROUP BY file_path',
      '    HAVING avg_runtime_ms > 10000',
      '),',
      'filtered_tests AS (',
      '    SELECT ' + sql.normalizeTestFilePath('tfm.test_file') + ' AS test_file',
      '    FROM ' + sql.testFileMappingsTable + ' tfm',
      '    PREWHERE tfm.' + sql.ciProjectPathFilter,
      "      AND (${section:singlequote} = 'All' OR tfm.section IN (${section:singlequote}))",
      "      AND (${stage:singlequote} = 'All' OR tfm.stage IN (${stage:singlequote}))",
      "      AND (${group:singlequote} = 'All' OR tfm.`group` IN (${group:singlequote}))",
      "      AND (${category:singlequote} = 'All' OR tfm.category IN (${category:singlequote}))",
      '    GROUP BY test_file',
      ')',
      'SELECT',
      '    s.file_path AS "Test File",',
      '    ROUND(s.avg_runtime_ms / 1000, 2) AS "Avg Runtime (s)",',
      '    COALESCE(c.files_covered, 0) AS "Files Covered",',
      '    ROUND(COALESCE(c.files_covered, 0) / (s.avg_runtime_ms / 1000), 4) AS "Coverage ROI"',
      'FROM slow_tests s',
      'LEFT JOIN code_coverage.flaky_test_coverage_impact c FINAL',
      '    ON s.normalized_path = c.test_file',
      'WHERE (',
      "  (${section:singlequote} = 'All' AND ${stage:singlequote} = 'All' AND ${group:singlequote} = 'All' AND ${category:singlequote} = 'All')",
      '  OR s.normalized_path IN (SELECT test_file FROM filtered_tests)',
      ')',
      'ORDER BY "Avg Runtime (s)" DESC',
      'LIMIT 50',
    ]),
    refId: 'A',
  }],
  title: 'Slow Test ROI (Runtime vs Files Covered)',
  type: 'table',
};

// Slow Test ROI explanation
local slowTestRoiExplanation = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 8, w: 5, x: 19, y: 47 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      - Tests taking >10s sorted by runtime.
      - Coverage ROI = files covered per second.
      - Low ROI = candidate for optimization.
    |||,
    mode: 'markdown',
  },
  pluginVersion: '12.3.1',
  title: '',
  transparent: true,
  type: 'text',
};

config.addStandardTemplates(
  basic.dashboard(
    'Coverage Actionables',
    tags=config.codeCoverageTags,
    includeEnvironmentTemplate=false,
    includeStandardEnvironmentAnnotations=false,
    time_from='now-7d',
    time_to='now',
  )
  .addLink(config.backToHealthCheckLink)
)
.addPanels([
  aboutTextPanel,
  testReliabilityRiskRow,
  quarantineRiskTablePanel,
  quarantineRiskLegend,
  flakyCoverageTable,
  flakyRiskLegend,
  criticalCoverageGapsRow,
  criticalLowCoverageTable,
  lineBranchGapScatter,
  lineFunctionGapScatter,
  coverageGapsTable,
  coverageGapsExplanation,
  testOptimizationRow,
  slowTestRoiTable,
  slowTestRoiExplanation,
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
