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

// Dashboard navigation links
local coverageTrendsLink = grafana.link.dashboards(
  'Coverage Trends',
  '',
  type='link',
  url='/d/dx-code-coverage-trends/dx-code-coverage-trends',
  icon='external link',
  keepTime=true,
  includeVars=true,
);

local actionablesLink = grafana.link.dashboards(
  'Actionables',
  '',
  type='link',
  url='/d/dx-code-coverage-actionables/dx-code-coverage-actionables',
  icon='external link',
  keepTime=true,
  includeVars=true,
);

local infrastructureLink = grafana.link.dashboards(
  'Infrastructure',
  '',
  type='link',
  url='/d/dx-code-coverage-infrastructure/dx-code-coverage-infrastructure',
  icon='external link',
  keepTime=true,
  includeVars=true,
);

local testToSourceLink = grafana.link.dashboards(
  'Test → Source',
  '',
  type='link',
  url='/d/dx-test-to-source/dx-test-to-source',
  icon='external link',
  keepTime=false,
  includeVars=false,
);

local sourceToTestLink = grafana.link.dashboards(
  'Source → Test',
  '',
  type='link',
  url='/d/dx-source-to-test/dx-source-to-test',
  icon='external link',
  keepTime=false,
  includeVars=false,
);

// SQL helpers
local flakyCoverageImpactFinal = '"code_coverage"."flaky_test_coverage_impact" FINAL';

// Panel factory functions
local clickHouseQueryTarget(rawSql) = {
  editorType: 'sql',
  format: 1,
  queryType: 'table',
  rawSql: rawSql,
  refId: 'A',
};

// About text panel
local aboutTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 8, w: 24, x: 0, y: 1 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      ### Understanding Code Coverage

      Code coverage measures how much of your source files are exercised when tests run. Think of it as a health check for your codebase.

      | Type | What it measures | Why it matters |
      |------|------------------|----------------|
      | **Line Coverage** | The percentage of code lines that were executed during testing | Tells you which code has been touched by tests. A line with 0% coverage has never been run by any test. |
      | **Branch Coverage** | The percentage of decision paths taken (e.g., both the `if` and `else` of a condition) | Catches untested edge cases. You might execute a line but only test the "happy path" and miss error handling. |
      | **Function Coverage** | The percentage of functions or methods that were called at least once | Quickly identifies dead zones—entire functions that no test ever invokes. |

      #### Drill-Down Dashboards

      Use the links in the top navigation bar to explore test-to-file relationships:

      | Dashboard | Use Case |
      |-----------|----------|
      | **Test → Source Lookup** | Select a test file to see which source files it touches, assess quarantine impact, and identify high-risk files |
      | **Source → Test Lookup** | Select a source file to see which tests touch it, useful when modifying code or debugging failures |

      #### Coverage by source type

      | Source | Line | Branch | Function |
      |--------|:----:|:------:|:--------:|
      | **RSpec** (Ruby backend) | Yes | Yes | No |
      | **Jest** (JavaScript frontend) | Yes | Yes | Yes |
      | **Workhorse** (Go) | Yes | No | No |

      If you see empty values for branch or function coverage, it's likely because that coverage type isn't available for that source.

      #### How to read these together

      - **High line, low branch** → Tests run through the code but skip edge cases and error paths
      - **High function, low line** → Functions are called but not thoroughly exercised
      - **All three high** → Good baseline, but remember: coverage shows what ran, not whether the tests actually verify correct behavior

      #### What's a good target?

      80% is a common goal. Focus on critical paths over chasing 100% everywhere.
    |||,
    mode: 'markdown',
  },
  title: '',
  type: 'text',
};

// Quick links text panel
local quickLinksTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 2, w: 24, x: 0, y: 9 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: '**Looking for specific files or tests?** Use [Test → Source Lookup](/d/dx-test-to-source/dx-test-to-source) to see what source files a test touches, or [Source → Test Lookup](/d/dx-source-to-test/dx-source-to-test) to find tests for a source file.',
    mode: 'markdown',
  },
  title: '',
  transparent: true,
  type: 'text',
};

// Total Source Files stat
local totalSourceFilesStat = {
  stableId: 'total-source-files',
  datasource: panels.clickHouseDatasource,
  description: 'Total number of distinct source files tracked in the coverage data.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
      unit: 'locale',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 10, x: 7, y: 11 },
  options: {
    colorMode: 'none',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'auto',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    showPercentChange: false,
    textMode: 'value',
    wideLayout: true,
  },
  targets: [clickHouseQueryTarget(|||
    SELECT
        COUNT(DISTINCT cm.file) AS "Total Files"
    FROM "code_coverage"."coverage_metrics" cm
    LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
    WHERE %s
      AND %s
  ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized])],
  title: 'Total Source Files',
  type: 'stat',
};

// Coverage Health text panel
local coverageHealthTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 6, w: 6, x: 0, y: 16 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      #### Coverage Health
      These metrics show what percentage of your codebase has strong test coverage (≥80%). Track trends over time to see if coverage is improving or declining.

      **[→ View Coverage Trends](/d/dx-code-coverage-trends/dx-code-coverage-trends)**
    |||,
    mode: 'markdown',
  },
  title: '',
  transparent: true,
  type: 'text',
};

// Strong Line Coverage stat
local strongLineCoverageStat = {
  stableId: 'strong-line-coverage',
  datasource: panels.clickHouseDatasource,
  description: 'Percentage of source files with line coverage ≥80%. Frontend = Jest, Backend = RSpec.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Trends →', url: '/d/dx-code-coverage-trends/dx-code-coverage-trends?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'semi-dark-red', value: 0 }, { color: 'semi-dark-yellow', value: 50 }, { color: 'semi-dark-green', value: 80 }] },
      unit: 'percent',
    },
    overrides: [
      { matcher: { id: 'byName', options: 'Frontend' }, properties: [{ id: 'color', value: { fixedColor: 'blue', mode: 'fixed' } }] },
      { matcher: { id: 'byName', options: 'Backend' }, properties: [{ id: 'color', value: { fixedColor: 'purple', mode: 'fixed' } }] },
    ],
  },
  gridPos: { h: 6, w: 6, x: 6, y: 16 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'horizontal',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: true },
    showPercentChange: false,
    textMode: 'value_and_name',
    wideLayout: true,
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT
          ROUND(
              countIf(cm.line_coverage >= 80 AND cm.ci_job_name LIKE '%%jest%%') * 100.0
              / NULLIF(countIf(cm.ci_job_name LIKE '%%jest%%'), 0),
              1
          ) AS "Frontend",
          ROUND(
              countIf(cm.line_coverage >= 80 AND cm.ci_job_name LIKE '%%rspec%%') * 100.0
              / NULLIF(countIf(cm.ci_job_name LIKE '%%rspec%%'), 0),
              1
          ) AS "Backend"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Strong Line Coverage',
  type: 'stat',
};

// Strong Branch Coverage stat
local strongBranchCoverageStat = {
  stableId: 'strong-branch-coverage',
  datasource: panels.clickHouseDatasource,
  description: 'Percentage of source files with branch coverage ≥80%. Frontend = Jest, Backend = RSpec.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Trends →', url: '/d/dx-code-coverage-trends/dx-code-coverage-trends?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'semi-dark-red', value: 0 }, { color: 'semi-dark-yellow', value: 50 }, { color: 'semi-dark-green', value: 80 }] },
      unit: 'percent',
    },
    overrides: [
      { matcher: { id: 'byName', options: 'Frontend' }, properties: [{ id: 'color', value: { fixedColor: 'blue', mode: 'fixed' } }] },
      { matcher: { id: 'byName', options: 'Backend' }, properties: [{ id: 'color', value: { fixedColor: 'purple', mode: 'fixed' } }] },
    ],
  },
  gridPos: { h: 6, w: 6, x: 12, y: 16 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'horizontal',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: true },
    showPercentChange: false,
    textMode: 'value_and_name',
    wideLayout: true,
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT
          ROUND(
              countIf(cm.branch_coverage >= 80 AND cm.ci_job_name LIKE '%%jest%%') * 100.0
              / NULLIF(countIf(cm.branch_coverage IS NOT NULL AND cm.ci_job_name LIKE '%%jest%%'), 0),
              1
          ) AS "Frontend",
          ROUND(
              countIf(cm.branch_coverage >= 80 AND cm.ci_job_name LIKE '%%rspec%%') * 100.0
              / NULLIF(countIf(cm.branch_coverage IS NOT NULL AND cm.ci_job_name LIKE '%%rspec%%'), 0),
              1
          ) AS "Backend"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Strong Branch Coverage',
  type: 'stat',
};

// Strong Function Coverage stat
local strongFunctionCoverageStat = {
  stableId: 'strong-function-coverage',
  datasource: panels.clickHouseDatasource,
  description: "Percentage of source files with function coverage ≥80%. Frontend only (Jest) - RSpec doesn't report function coverage.",
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Trends →', url: '/d/dx-code-coverage-trends/dx-code-coverage-trends?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'semi-dark-red', value: 0 }, { color: 'semi-dark-yellow', value: 50 }, { color: 'semi-dark-green', value: 80 }] },
      unit: 'percent',
    },
    overrides: [
      { matcher: { id: 'byName', options: 'Frontend' }, properties: [{ id: 'color', value: { fixedColor: 'blue', mode: 'fixed' } }] },
    ],
  },
  gridPos: { h: 6, w: 6, x: 18, y: 16 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'horizontal',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: true },
    showPercentChange: false,
    textMode: 'value_and_name',
    wideLayout: true,
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT
          ROUND(
              countIf(cm.function_coverage >= 80 AND cm.ci_job_name LIKE '%%jest%%') * 100.0
              / NULLIF(countIf(cm.function_coverage IS NOT NULL AND cm.ci_job_name LIKE '%%jest%%'), 0),
              1
          ) AS "Frontend"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Strong Function Coverage',
  type: 'stat',
};

// Problem Areas text panel
local problemAreasTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 8, w: 6, x: 0, y: 22 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      #### Problem Areas
      Files with zero coverage or unreliable test coverage need attention. Zero coverage means untested code; flaky coverage means tests that sometimes fail and may be quarantined.

      **[→ View Actionables](/d/dx-code-coverage-actionables/dx-code-coverage-actionables)**
    |||,
    mode: 'markdown',
  },
  title: '',
  transparent: true,
  type: 'text',
};

// Zero Line Coverage stat
local zeroLineCoverageStat = {
  stableId: 'zero-line-coverage',
  datasource: panels.clickHouseDatasource,
  description: 'Number of source files with 0% line coverage - no lines of code have been executed by tests.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Actionables →', url: '/d/dx-code-coverage-actionables/dx-code-coverage-actionables?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'semi-dark-green', value: 0 }, { color: 'semi-dark-red', value: 1 }] },
      unit: 'locale',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 6, y: 22 },
  options: {
    colorMode: 'value',
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
          COUNT(DISTINCT cm.file) AS "Zero Line Coverage"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.line_coverage = 0
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Zero Line Coverage',
  type: 'stat',
};

// Zero Branch Coverage stat
local zeroBranchCoverageStat = {
  stableId: 'zero-branch-coverage',
  datasource: panels.clickHouseDatasource,
  description: 'Number of source files with 0% branch coverage - no conditional branches (if/else, switch) have been tested.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Actionables →', url: '/d/dx-code-coverage-actionables/dx-code-coverage-actionables?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'semi-dark-green', value: 0 }, { color: 'semi-dark-red', value: 1 }] },
      unit: 'locale',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 12, y: 22 },
  options: {
    colorMode: 'value',
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
          COUNT(DISTINCT cm.file) AS "Zero Branch Coverage"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.branch_coverage = 0
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Zero Branch Coverage',
  type: 'stat',
};

// Zero Function Coverage stat
local zeroFunctionCoverageStat = {
  stableId: 'zero-function-coverage',
  datasource: panels.clickHouseDatasource,
  description: 'Number of source files with 0% function coverage - no functions or methods have been called by tests.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Actionables →', url: '/d/dx-code-coverage-actionables/dx-code-coverage-actionables?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'semi-dark-green', value: 0 }, { color: 'semi-dark-red', value: 1 }] },
      unit: 'locale',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 18, y: 22 },
  options: {
    colorMode: 'value',
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
          COUNT(DISTINCT cm.file) AS "Zero Function Coverage"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND cm.function_coverage = 0
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Zero Function Coverage',
  type: 'stat',
};

// Quarantine Risk stat
local quarantineRiskStat = {
  stableId: 'quarantine-risk',
  datasource: panels.clickHouseDatasource,
  description: 'Source files at risk due to quarantined tests. Critical = all tests fully quarantined. High = all tests have some quarantine.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Actionables →', url: '/d/dx-code-coverage-actionables/dx-code-coverage-actionables?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 5 }, { color: 'red', value: 20 }] },
      unit: 'none',
    },
    overrides: [
      { matcher: { id: 'byName', options: 'Critical' }, properties: [{ id: 'color', value: { fixedColor: 'red', mode: 'fixed' } }] },
      { matcher: { id: 'byName', options: 'High' }, properties: [{ id: 'color', value: { fixedColor: 'orange', mode: 'fixed' } }] },
    ],
  },
  gridPos: { h: 4, w: 7, x: 8, y: 26 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'horizontal',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: true },
    showPercentChange: false,
    textMode: 'value_and_name',
    wideLayout: true,
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      WITH quarantine_stats AS (
          SELECT
              %s AS source_file,
              SUM(CASE WHEN tqs.quarantined_cases >= tqs.total_cases THEN 1 ELSE 0 END) AS fully_quarantined,
              SUM(CASE WHEN tqs.quarantined_cases < tqs.total_cases THEN 1 ELSE 0 END) AS partially_quarantined
          FROM %s tfm
          INNER JOIN (
              SELECT test_file, total_cases, quarantined_cases
              FROM (
                  SELECT
                      test_file,
                      uniqMerge(total_cases) AS total_cases,
                      uniqIfMerge(quarantined_cases) AS quarantined_cases
                  FROM test_metrics.test_file_quarantine_summary
                  WHERE %s
                  GROUP BY test_file
              )
              WHERE quarantined_cases > 0
          ) tqs ON %s = tqs.test_file
          PREWHERE tfm.%s
          GROUP BY source_file
      )
      SELECT
          countIf(tc.test_count <= q.fully_quarantined) AS "Critical",
          countIf(tc.test_count > q.fully_quarantined AND tc.test_count <= q.fully_quarantined + q.partially_quarantined) AS "High"
      FROM (
          SELECT %s AS source_file, COUNT(DISTINCT %s) AS test_count
          FROM %s
          PREWHERE %s
          GROUP BY source_file
      ) tc
      INNER JOIN quarantine_stats q ON tc.source_file = q.source_file
    ||| % [
      sql.normalizeSourceFilePath('tfm.source_file'),
      sql.testFileMappingsTable,
      sql.timeRangeFilter('date'),
      sql.normalizeTestFilePath('tfm.test_file'),
      sql.ciProjectPathFilter + " AND (${section:singlequote} = 'All' OR tfm.section IN (${section:singlequote})) AND (${stage:singlequote} = 'All' OR tfm.stage IN (${stage:singlequote})) AND (${group:singlequote} = 'All' OR tfm.`group` IN (${group:singlequote})) AND (${category:singlequote} = 'All' OR tfm.category IN (${category:singlequote}))",
      sql.normalizeSourceFilePath('source_file'),
      sql.normalizeTestFilePath('test_file'),
      sql.testFileMappingsTable,
      sql.ciProjectPathFilter + " AND (${section:singlequote} = 'All' OR section IN (${section:singlequote})) AND (${stage:singlequote} = 'All' OR stage IN (${stage:singlequote})) AND (${group:singlequote} = 'All' OR `group` IN (${group:singlequote})) AND (${category:singlequote} = 'All' OR category IN (${category:singlequote}))",
    ],
    refId: 'A',
  }],
  title: 'Quarantine Risk',
  type: 'stat',
};

// Flaky Tests with Sole Coverage stat
local flakyTestsSoleCoverageStat = {
  stableId: 'flaky-tests-sole-coverage',
  datasource: panels.clickHouseDatasource,
  description: 'Flaky tests with sole coverage on source files. Fully Flaky = all test cases flaky. Partially Flaky = some test cases flaky.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Actionables →', url: '/d/dx-code-coverage-actionables/dx-code-coverage-actionables?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 5 }, { color: 'red', value: 20 }] },
      unit: 'none',
    },
    overrides: [
      { matcher: { id: 'byName', options: 'Fully Flaky' }, properties: [{ id: 'color', value: { fixedColor: 'red', mode: 'fixed' } }] },
      { matcher: { id: 'byName', options: 'Partially Flaky' }, properties: [{ id: 'color', value: { fixedColor: 'orange', mode: 'fixed' } }] },
    ],
  },
  gridPos: { h: 4, w: 7, x: 15, y: 26 },
  options: {
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
    orientation: 'horizontal',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: true },
    showPercentChange: false,
    textMode: 'value_and_name',
    wideLayout: true,
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT
          countIf(flaky_cases >= total_cases) AS "Fully Flaky",
          countIf(flaky_cases > 0 AND flaky_cases < total_cases) AS "Partially Flaky"
      FROM (
          SELECT test_file, total_cases, flaky_cases
          FROM (
              SELECT
                  fs.test_file,
                  uniqMerge(fs.total_cases) AS total_cases,
                  uniqIfMerge(fs.flaky_cases) AS flaky_cases
              FROM test_metrics.test_file_flaky_summary fs
              INNER JOIN "code_coverage"."flaky_test_coverage_impact" c FINAL ON fs.test_file = c.test_file
              WHERE %s
                AND c.sole_coverage_files > 0
              GROUP BY fs.test_file
          )
          WHERE flaky_cases > 0
      )
    ||| % [sql.timeRangeFilter('date')],
    refId: 'A',
  }],
  title: 'Flaky Tests with Sole Coverage',
  type: 'stat',
};

// Test Infrastructure text panel
local testInfrastructureTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 6, w: 6, x: 0, y: 30 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      #### Test Infrastructure
      Understand how your code is tested. Dual coverage means files are tested by both unit and integration tests, providing stronger confidence.

      **[→ View Infrastructure](/d/dx-code-coverage-infrastructure/dx-code-coverage-infrastructure)**
    |||,
    mode: 'markdown',
  },
  title: '',
  transparent: true,
  type: 'text',
};

// Unit Only % stat
local unitTestOnlyStat = {
  stableId: 'unit-test-only',
  datasource: panels.clickHouseDatasource,
  description: 'Percentage of source files covered only by unit tests (no integration test coverage). Lower is better - these files lack integration test safety.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Infrastructure →', url: '/d/dx-code-coverage-infrastructure/dx-code-coverage-infrastructure?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 30 }, { color: 'red', value: 50 }] },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 6, y: 30 },
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
      SELECT ROUND(countIf(is_responsible = true AND is_dependent = false) * 100.0 / count(), 1) AS "Unit Only %%"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Unit Only %',
  type: 'stat',
};

// Dual Coverage % stat
local dualCoverageStat = {
  stableId: 'dual-coverage',
  datasource: panels.clickHouseDatasource,
  description: 'Percentage of source files with both unit test (responsible) AND integration test (dependent) coverage. Higher is better - indicates more robust test coverage.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Infrastructure →', url: '/d/dx-code-coverage-infrastructure/dx-code-coverage-infrastructure?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 30 }, { color: 'green', value: 50 }] },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 12, y: 30 },
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
      SELECT ROUND(countIf(is_responsible = true AND is_dependent = true) * 100.0 / count(), 1) AS "Dual Coverage %%"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Dual Coverage %',
  type: 'stat',
};

// Integration Only % stat
local integrationOnlyStat = {
  stableId: 'integration-only',
  datasource: panels.clickHouseDatasource,
  description: 'Percentage of source files covered only by integration tests (no unit test coverage). Lower is better - these files have slow feedback loops.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [{ targetBlank: false, title: 'View Infrastructure →', url: '/d/dx-code-coverage-infrastructure/dx-code-coverage-infrastructure?${__url_time_range}&${__all_variables}' }],
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 20 }, { color: 'orange', value: 40 }] },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 4, w: 6, x: 18, y: 30 },
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
      SELECT ROUND(countIf(is_responsible = false AND is_dependent = true) * 100.0 / count(), 1) AS "Integration Only %%"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Integration Only %',
  type: 'stat',
};

// Coverage Trends by Source Type timeseries
local coverageTrendsTimeseries = {
  stableId: 'coverage-trends',
  datasource: panels.clickHouseDatasource,
  description: "Average line, branch, and function coverage over time. Use filters above to track your team's coverage trends, or view All for project-wide trends.",
  fieldConfig: {
    defaults: {
      color: { mode: 'palette-classic' },
      custom: {
        axisBorderShow: false,
        axisCenteredZero: false,
        axisColorMode: 'text',
        axisLabel: '',
        axisPlacement: 'auto',
        axisSoftMax: 100,
        axisSoftMin: 0,
        barAlignment: 0,
        barWidthFactor: 0.6,
        drawStyle: 'line',
        fillOpacity: 0,
        gradientMode: 'opacity',
        hideFrom: { legend: false, tooltip: false, viz: false },
        insertNulls: false,
        lineInterpolation: 'linear',
        lineStyle: { fill: 'solid' },
        lineWidth: 1,
        pointSize: 5,
        scaleDistribution: { type: 'linear' },
        showPoints: 'auto',
        spanNulls: false,
        stacking: { group: 'A', mode: 'none' },
        thresholdsStyle: { mode: 'off' },
      },
      mappings: [],
      thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
    },
    overrides: [],
  },
  gridPos: { h: 7, w: 24, x: 0, y: 36 },
  options: {
    legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
    tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
  },
  targets: [{
    editorType: 'sql',
    format: 1,
    queryType: 'table',
    rawSql: |||
      SELECT
          cm.timestamp AS time,
          ROUND(avgIf(cm.line_coverage, cm.ci_job_name LIKE '%jest%'), 2) AS frontend_line_cov,
          ROUND(avgIf(cm.branch_coverage, cm.ci_job_name LIKE '%jest%'), 2) AS frontend_branch_cov,
          ROUND(avgIf(cm.function_coverage, cm.ci_job_name LIKE '%jest%'), 2) AS frontend_func_cov,
          ROUND(avgIf(cm.line_coverage, cm.ci_job_name LIKE '%rspec%'), 2) AS backend_line_cov,
          ROUND(avgIf(cm.branch_coverage, cm.ci_job_name LIKE '%rspec%'), 2) AS backend_branch_cov
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE (cm.line_coverage IS NOT NULL OR cm.branch_coverage IS NOT NULL OR cm.function_coverage IS NOT NULL)
        AND CASE WHEN ${section:singlequote} = 'All' THEN true WHEN ${section:singlequote} = 'Uncategorized' THEN co.section IS NULL ELSE co.section = ${section:singlequote} END
        AND CASE WHEN ${stage:singlequote} = 'All' THEN true WHEN ${stage:singlequote} = 'Uncategorized' THEN co.stage IS NULL ELSE co.stage = ${stage:singlequote} END
        AND CASE WHEN ${group:singlequote} = 'All' THEN true WHEN ${group:singlequote} = 'Uncategorized' THEN co.group IS NULL ELSE co.group = ${group:singlequote} END
        AND CASE WHEN ${category:singlequote} = 'All' THEN true WHEN ${category:singlequote} = 'Uncategorized' THEN cm.category IS NULL ELSE cm.category = ${category:singlequote} END
        AND (${source_file_type:singlequote} = 'All' OR cm.source_file_type = ${source_file_type:singlequote})
      GROUP BY cm.timestamp
      ORDER BY time ASC
    |||,
    refId: 'A',
  }],
  title: 'Coverage Trends by Source Type',
  type: 'timeseries',
};

// Build the dashboard
config.addStandardTemplates(
  basic.dashboard(
    'Code Coverage Health Check',
    tags=config.codeCoverageTags,
    includeEnvironmentTemplate=false,
    includeStandardEnvironmentAnnotations=false,
    defaultDatasource=datasource,
    time_from='now-7d',
    time_to='now',
  )
)
.addLink(coverageTrendsLink)
.addLink(actionablesLink)
.addLink(infrastructureLink)
.addLink(testToSourceLink)
.addLink(sourceToTestLink)
.addPanels([
  // About row
  grafana.row.new(title='About This Dashboard', collapse=false)
  + { gridPos: { h: 1, w: 24, x: 0, y: 0 } },

  aboutTextPanel,
  quickLinksTextPanel,
  totalSourceFilesStat,

  // Health Check row
  grafana.row.new(title='Health Check', collapse=false)
  + { gridPos: { h: 1, w: 24, x: 0, y: 15 } },

  coverageHealthTextPanel,
  strongLineCoverageStat,
  strongBranchCoverageStat,
  strongFunctionCoverageStat,
  problemAreasTextPanel,
  zeroLineCoverageStat,
  zeroBranchCoverageStat,
  zeroFunctionCoverageStat,
  quarantineRiskStat,
  flakyTestsSoleCoverageStat,
  testInfrastructureTextPanel,
  unitTestOnlyStat,
  dualCoverageStat,
  integrationOnlyStat,
  coverageTrendsTimeseries,
])
+ {
  time: { from: 'now-7d', to: 'now' },
  editable: false,
  // Filter out PROMETHEUS_DS and environment since this dashboard uses ClickHouse
  templating+: {
    list: std.filter(
      function(t) t.name != 'PROMETHEUS_DS' && t.name != 'environment',
      super.list
    ),
  },
}
