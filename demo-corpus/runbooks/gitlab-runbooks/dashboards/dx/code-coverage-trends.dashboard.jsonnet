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

// Generic helper for table column with gradient background coloring
local colorBackgroundOverride(columnName, thresholds, columnWidth=null, unit=null) = {
  matcher: { id: 'byName', options: columnName },
  properties: [
                { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
                { id: 'thresholds', value: thresholds },
              ] + (if columnWidth != null then [{ id: 'custom.width', value: columnWidth }] else [])
              + (if unit != null then [{ id: 'unit', value: unit }] else []),
};

local categoryFilterLinkOverride(columnWidth=null) = {
  matcher: { id: 'byName', options: 'Category' },
  properties: [{
    id: 'links',
    value: [{
      title: 'Filter by Category',
      url: '/d/${__dashboard.uid}/${__dashboard}?var-category=${__value.raw}',
    }],
  }] + (if columnWidth != null then [{ id: 'custom.width', value: columnWidth }] else []),
};

// Template variables
// Custom template for this dashboard
local groupByTemplate = template.custom(
  'group_by',
  'section,stage,group,category',
  'section',
);

// About text panel
local aboutTextPanel = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 5, w: 24, x: 0, y: 0 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: |||
      ### Coverage Trends

      Track coverage metrics over time by category, stage, and product level.

      - **Coverage by Product Level**: Line, branch, and function coverage trends
      - **Category Gains/Drops**: Identify improving or regressing categories
      - **Category Trends**: Drill down into specific category coverage
    |||,
    mode: 'markdown',
  },
  title: '',
  type: 'text',
};

// Line Coverage by Product Level bar gauge
local lineCoverageByProductLevel = {
  datasource: panels.clickHouseDatasource,
  description: 'Line coverage percentage by organizational section. Bars fill toward 100% target with threshold-based coloring.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      links: [],
      mappings: [],
      max: 100,
      min: 0,
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'text', value: 0 },
          { color: 'semi-dark-red', value: 0.01 },
          { color: 'semi-dark-yellow', value: 50 },
          { color: 'semi-dark-green', value: 80 },
        ],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 8, x: 0, y: 5 },
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
    meta: { builderOptions: { columns: [], database: '', limit: 1000, mode: 'list', queryType: 'table', table: '' } },
    pluginVersion: '4.11.2',
    queryType: 'table',
    rawSql: |||
      SELECT
          CASE ${group_by:singlequote}
              WHEN 'section' THEN CASE WHEN co.section IS NULL OR co.section = '' THEN 'null' ELSE co.section END
              WHEN 'stage' THEN CASE WHEN co.stage IS NULL OR co.stage = '' THEN 'null' ELSE co.stage END
              WHEN 'group' THEN CASE WHEN co.group IS NULL OR co.group = '' THEN 'null' ELSE co.group END
              WHEN 'category' THEN CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END
          END AS "Dimension",
          ROUND(AVG(cm.line_coverage), 2) AS "Line Coverage"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
      GROUP BY
          CASE ${group_by:singlequote}
              WHEN 'section' THEN CASE WHEN co.section IS NULL OR co.section = '' THEN 'null' ELSE co.section END
              WHEN 'stage' THEN CASE WHEN co.stage IS NULL OR co.stage = '' THEN 'null' ELSE co.stage END
              WHEN 'group' THEN CASE WHEN co.group IS NULL OR co.group = '' THEN 'null' ELSE co.group END
              WHEN 'category' THEN CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END
          END
      ORDER BY "Line Coverage" ASC
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Line Coverage by Product Level',
  type: 'bargauge',
};

// Branch Coverage by Product Level bar gauge
local branchCoverageByProductLevel = {
  datasource: panels.clickHouseDatasource,
  description: 'Branch coverage percentage grouped by selected dimension. Bars fill toward 100% target with threshold-based coloring.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      max: 100,
      min: 0,
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'text', value: 0 },
          { color: 'semi-dark-red', value: 0.01 },
          { color: 'semi-dark-yellow', value: 50 },
          { color: 'semi-dark-green', value: 80 },
        ],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 8, x: 8, y: 5 },
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
    meta: { builderOptions: { columns: [], database: '', limit: 1000, mode: 'list', queryType: 'table', table: '' } },
    pluginVersion: '4.11.2',
    queryType: 'table',
    rawSql: |||
      SELECT
          CASE ${group_by:singlequote}
              WHEN 'section' THEN CASE WHEN co.section IS NULL OR co.section = '' THEN 'null' ELSE co.section END
              WHEN 'stage' THEN CASE WHEN co.stage IS NULL OR co.stage = '' THEN 'null' ELSE co.stage END
              WHEN 'group' THEN CASE WHEN co.group IS NULL OR co.group = '' THEN 'null' ELSE co.group END
              WHEN 'category' THEN CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END
          END AS "Dimension",
          ROUND(AVG(cm.branch_coverage), 2) AS "Branch Coverage"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
      GROUP BY
          CASE ${group_by:singlequote}
              WHEN 'section' THEN CASE WHEN co.section IS NULL OR co.section = '' THEN 'null' ELSE co.section END
              WHEN 'stage' THEN CASE WHEN co.stage IS NULL OR co.stage = '' THEN 'null' ELSE co.stage END
              WHEN 'group' THEN CASE WHEN co.group IS NULL OR co.group = '' THEN 'null' ELSE co.group END
              WHEN 'category' THEN CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END
          END
      ORDER BY "Branch Coverage" ASC
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Branch Coverage by Product Level',
  type: 'bargauge',
};

// Function Coverage by Product Level bar gauge
local functionCoverageByProductLevel = {
  datasource: panels.clickHouseDatasource,
  description: 'Function coverage percentage grouped by selected dimension. Bars fill toward 100% target with threshold-based coloring.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      max: 100,
      min: 0,
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'text', value: 0 },
          { color: 'semi-dark-red', value: 0.01 },
          { color: 'semi-dark-green', value: 80 },
          { color: '#EAB839', value: 90 },
        ],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 8, x: 16, y: 5 },
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
    meta: { builderOptions: { columns: [], database: '', limit: 1000, mode: 'list', queryType: 'table', table: '' } },
    pluginVersion: '4.11.2',
    queryType: 'table',
    rawSql: |||
      SELECT
          CASE ${group_by:singlequote}
              WHEN 'section' THEN CASE WHEN co.section IS NULL OR co.section = '' THEN 'null' ELSE co.section END
              WHEN 'stage' THEN CASE WHEN co.stage IS NULL OR co.stage = '' THEN 'null' ELSE co.stage END
              WHEN 'group' THEN CASE WHEN co.group IS NULL OR co.group = '' THEN 'null' ELSE co.group END
              WHEN 'category' THEN CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END
          END AS "Dimension",
          ROUND(AVG(cm.function_coverage), 2) AS "Function Coverage"
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE %s
        AND %s
      GROUP BY
          CASE ${group_by:singlequote}
              WHEN 'section' THEN CASE WHEN co.section IS NULL OR co.section = '' THEN 'null' ELSE co.section END
              WHEN 'stage' THEN CASE WHEN co.stage IS NULL OR co.stage = '' THEN 'null' ELSE co.stage END
              WHEN 'group' THEN CASE WHEN co.group IS NULL OR co.group = '' THEN 'null' ELSE co.group END
              WHEN 'category' THEN CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END
          END
      ORDER BY "Function Coverage" ASC
    ||| % [sql.latestCoverageMetricsSubqueryWithUncategorized, sql.categoryOwnerFilterConditionsWithUncategorized],
    refId: 'A',
  }],
  title: 'Function Coverage by Product Level',
  type: 'bargauge',
};

// Category Coverage Gains table
local categoryCoverageGainsTable = {
  stableId: 'category-coverage-gains-table',
  datasource: panels.clickHouseDatasource,
  description: 'Categories with the biggest coverage improvements since yesterday.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      custom: {
        align: 'auto',
        cellOptions: { type: 'auto' },
        footer: { reducers: [] },
        hideFrom: { viz: false },
        inspect: false,
      },
      decimals: 2,
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'transparent', value: 0 },
          { color: 'green', value: 0.01 },
          { color: 'semi-dark-green', value: 2 },
          { color: 'dark-green', value: 5 },
        ],
      },
    },
    overrides: [
      colorBackgroundOverride('Line Delta', { mode: 'absolute', steps: [{ color: 'transparent', value: 0 }, { color: 'green', value: 0.01 }, { color: 'semi-dark-green', value: 2 }, { color: 'dark-green', value: 5 }] }),
      colorBackgroundOverride('Branch Delta', { mode: 'absolute', steps: [{ color: 'transparent', value: 0 }, { color: 'green', value: 0.01 }, { color: 'semi-dark-green', value: 2 }, { color: 'dark-green', value: 5 }] }),
      colorBackgroundOverride('Function Delta', { mode: 'absolute', steps: [{ color: 'transparent', value: 0 }, { color: 'green', value: 0.01 }, { color: 'semi-dark-green', value: 2 }, { color: 'dark-green', value: 5 }] }),
      categoryFilterLinkOverride(),
    ],
  },
  gridPos: { h: 8, w: 12, x: 0, y: 13 },
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
    meta: { builderOptions: { columns: [], database: '', limit: 1000, mode: 'list', queryType: 'table', table: '' } },
    pluginVersion: '4.11.2',
    queryType: 'table',
    rawSql: |||
      WITH daily_category_coverage AS (
          SELECT
              toDate(timestamp) AS day,
              category,
              ROUND(AVG(line_coverage), 2) AS avg_line,
              ROUND(AVG(branch_coverage), 2) AS avg_branch,
              ROUND(AVG(function_coverage), 2) AS avg_function
          FROM "code_coverage"."coverage_metrics"
          WHERE line_coverage IS NOT NULL
            AND timestamp >= $__fromTime AND timestamp <= $__toTime
            AND (${source_file_type:singlequote} = 'All' OR source_file_type = ${source_file_type:singlequote})
          GROUP BY day, category
      ),
      latest_day AS (
          SELECT MAX(day) AS d FROM daily_category_coverage
      ),
      previous_day AS (
          SELECT MAX(day) AS d FROM daily_category_coverage WHERE day < (SELECT d FROM latest_day)
      )
      SELECT
          CASE WHEN curr.category IS NULL OR curr.category = '' THEN 'null' ELSE curr.category END AS "Category",
          ROUND(curr.avg_line - prev.avg_line, 2) AS "Line Delta",
          ROUND(curr.avg_branch - prev.avg_branch, 2) AS "Branch Delta",
          ROUND(curr.avg_function - prev.avg_function, 2) AS "Function Delta"
      FROM daily_category_coverage curr
      JOIN daily_category_coverage prev ON curr.category = prev.category
      LEFT JOIN "code_coverage"."category_owners" co ON curr.category = co.category
      WHERE curr.day = (SELECT d FROM latest_day)
        AND prev.day = (SELECT d FROM previous_day)
        AND (curr.avg_line > prev.avg_line OR curr.avg_branch > prev.avg_branch OR curr.avg_function > prev.avg_function)
        AND CASE WHEN ${section:singlequote} = 'All' THEN true WHEN ${section:singlequote} = 'Uncategorized' THEN co.section IS NULL ELSE co.section = ${section:singlequote} END
        AND CASE WHEN ${stage:singlequote} = 'All' THEN true WHEN ${stage:singlequote} = 'Uncategorized' THEN co.stage IS NULL ELSE co.stage = ${stage:singlequote} END
        AND CASE WHEN ${group:singlequote} = 'All' THEN true WHEN ${group:singlequote} = 'Uncategorized' THEN co.group IS NULL ELSE co.group = ${group:singlequote} END
        AND CASE WHEN ${category:singlequote} = 'All' THEN true WHEN ${category:singlequote} = 'Uncategorized' THEN curr.category IS NULL ELSE curr.category = ${category:singlequote} END
      ORDER BY (curr.avg_line - prev.avg_line) + (curr.avg_branch - prev.avg_branch) + (curr.avg_function - prev.avg_function) DESC
    |||,
    refId: 'A',
  }],
  title: 'Category Coverage Gains',
  type: 'table',
};

// Category Coverage Drops table
local categoryCoverageDropsTable = {
  stableId: 'category-coverage-drops-table',
  datasource: panels.clickHouseDatasource,
  description: 'Categories with coverage decreases since yesterday. Investigate potential regressions.',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      custom: {
        align: 'auto',
        cellOptions: { type: 'auto' },
        footer: { reducers: [] },
        hideFrom: { viz: false },
        inspect: false,
      },
      decimals: 2,
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'transparent', value: 0 },
          { color: 'dark-red', value: -5 },
          { color: 'semi-dark-red', value: -2 },
          { color: 'red', value: -0.01 },
        ],
      },
    },
    overrides: [
      colorBackgroundOverride('Line Delta', { mode: 'absolute', steps: [{ color: 'transparent', value: 0 }, { color: 'dark-red', value: -5 }, { color: 'semi-dark-red', value: -2 }, { color: 'red', value: -0.01 }] }),
      colorBackgroundOverride('Branch Delta', { mode: 'absolute', steps: [{ color: 'transparent', value: 0 }, { color: 'dark-red', value: -5 }, { color: 'semi-dark-red', value: -2 }, { color: 'red', value: -0.01 }] }),
      colorBackgroundOverride('Function Delta', { mode: 'absolute', steps: [{ color: 'transparent', value: 0 }, { color: 'dark-red', value: -5 }, { color: 'semi-dark-red', value: -2 }, { color: 'red', value: -0.01 }] }),
      categoryFilterLinkOverride(),
    ],
  },
  gridPos: { h: 8, w: 12, x: 12, y: 13 },
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
    meta: { builderOptions: { columns: [], database: '', limit: 1000, mode: 'list', queryType: 'table', table: '' } },
    pluginVersion: '4.11.2',
    queryType: 'table',
    rawSql: |||
      WITH daily_category_coverage AS (
          SELECT
              toDate(timestamp) AS day,
              category,
              ROUND(AVG(line_coverage), 2) AS avg_line,
              ROUND(AVG(branch_coverage), 2) AS avg_branch,
              ROUND(AVG(function_coverage), 2) AS avg_function
          FROM "code_coverage"."coverage_metrics"
          WHERE line_coverage IS NOT NULL
            AND timestamp >= $__fromTime AND timestamp <= $__toTime
            AND (${source_file_type:singlequote} = 'All' OR source_file_type = ${source_file_type:singlequote})
          GROUP BY day, category
      ),
      latest_day AS (
          SELECT MAX(day) AS d FROM daily_category_coverage
      ),
      previous_day AS (
          SELECT MAX(day) AS d FROM daily_category_coverage WHERE day < (SELECT d FROM latest_day)
      )
      SELECT
          CASE WHEN curr.category IS NULL OR curr.category = '' THEN 'null' ELSE curr.category END AS "Category",
          ROUND(curr.avg_line - prev.avg_line, 2) AS "Line Delta",
          ROUND(curr.avg_branch - prev.avg_branch, 2) AS "Branch Delta",
          ROUND(curr.avg_function - prev.avg_function, 2) AS "Function Delta"
      FROM daily_category_coverage curr
      JOIN daily_category_coverage prev ON curr.category = prev.category
      LEFT JOIN "code_coverage"."category_owners" co ON curr.category = co.category
      WHERE curr.day = (SELECT d FROM latest_day)
        AND prev.day = (SELECT d FROM previous_day)
        AND (curr.avg_line < prev.avg_line OR curr.avg_branch < prev.avg_branch OR curr.avg_function < prev.avg_function)
        AND CASE WHEN ${section:singlequote} = 'All' THEN true WHEN ${section:singlequote} = 'Uncategorized' THEN co.section IS NULL ELSE co.section = ${section:singlequote} END
        AND CASE WHEN ${stage:singlequote} = 'All' THEN true WHEN ${stage:singlequote} = 'Uncategorized' THEN co.stage IS NULL ELSE co.stage = ${stage:singlequote} END
        AND CASE WHEN ${group:singlequote} = 'All' THEN true WHEN ${group:singlequote} = 'Uncategorized' THEN co.group IS NULL ELSE co.group = ${group:singlequote} END
        AND CASE WHEN ${category:singlequote} = 'All' THEN true WHEN ${category:singlequote} = 'Uncategorized' THEN curr.category IS NULL ELSE curr.category = ${category:singlequote} END
      ORDER BY (curr.avg_line - prev.avg_line) + (curr.avg_branch - prev.avg_branch) + (curr.avg_function - prev.avg_function) ASC
    |||,
    refId: 'A',
  }],
  title: 'Category Coverage Drops',
  type: 'table',
};

// Category Line Coverage Trend timeseries
local categoryLineCoverageTrend = {
  datasource: panels.clickHouseDatasource,
  description: 'Line coverage trend over time by category. Use category filter to focus on specific categories.',
  fieldConfig: {
    defaults: {
      color: { mode: 'palette-classic' },
      custom: {
        axisBorderShow: false,
        axisCenteredZero: false,
        axisColorMode: 'text',
        axisLabel: '',
        axisPlacement: 'auto',
        barAlignment: -1,
        barWidthFactor: 0.6,
        drawStyle: 'line',
        fillOpacity: 0,
        gradientMode: 'none',
        hideFrom: { legend: false, tooltip: false, viz: false },
        insertNulls: false,
        lineInterpolation: 'linear',
        lineStyle: { fill: 'solid' },
        lineWidth: 1,
        pointSize: 5,
        scaleDistribution: { type: 'linear' },
        showPoints: 'auto',
        showValues: false,
        spanNulls: false,
        stacking: { group: 'A', mode: 'none' },
        thresholdsStyle: { mode: 'off' },
      },
      displayName: '${__field.labels.category}',
      fieldMinMax: false,
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 8, x: 0, y: 21 },
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
          ROUND(AVG(cm.line_coverage), 2) AS line_coverage,
          CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END AS category
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE cm.line_coverage IS NOT NULL
        AND %s
        AND CASE WHEN ${section:singlequote} = 'All' THEN true WHEN ${section:singlequote} = 'Uncategorized' THEN co.section IS NULL ELSE co.section = ${section:singlequote} END
        AND CASE WHEN ${stage:singlequote} = 'All' THEN true WHEN ${stage:singlequote} = 'Uncategorized' THEN co.stage IS NULL ELSE co.stage = ${stage:singlequote} END
        AND CASE WHEN ${group:singlequote} = 'All' THEN true WHEN ${group:singlequote} = 'Uncategorized' THEN co.group IS NULL ELSE co.group = ${group:singlequote} END
        AND CASE WHEN ${category:singlequote} = 'All' THEN true WHEN ${category:singlequote} = 'Uncategorized' THEN cm.category IS NULL ELSE cm.category = ${category:singlequote} END
        AND (${source_file_type:singlequote} = 'All' OR cm.source_file_type = ${source_file_type:singlequote})
      GROUP BY cm.timestamp, category
      ORDER BY time ASC
    ||| % [sql.timeRangeFilter('timestamp')],
    refId: 'A',
  }],
  title: 'Category Coverage Trend',
  transformations: [{ id: 'prepareTimeSeries', options: { format: 'multi' } }],
  type: 'timeseries',
};

// Category Branch Coverage Trend timeseries
local categoryBranchCoverageTrend = {
  datasource: panels.clickHouseDatasource,
  description: 'Branch coverage trend over time by category.',
  fieldConfig: {
    defaults: {
      color: { mode: 'palette-classic' },
      custom: {
        axisBorderShow: false,
        axisCenteredZero: false,
        axisColorMode: 'text',
        axisLabel: '',
        axisPlacement: 'auto',
        barAlignment: -1,
        barWidthFactor: 0.6,
        drawStyle: 'line',
        fillOpacity: 0,
        gradientMode: 'none',
        hideFrom: { legend: false, tooltip: false, viz: false },
        insertNulls: false,
        lineInterpolation: 'linear',
        lineStyle: { fill: 'solid' },
        lineWidth: 1,
        pointSize: 5,
        scaleDistribution: { type: 'linear' },
        showPoints: 'auto',
        showValues: false,
        spanNulls: false,
        stacking: { group: 'A', mode: 'none' },
        thresholdsStyle: { mode: 'off' },
      },
      displayName: '${__field.labels.category}',
      fieldMinMax: false,
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 8, x: 8, y: 21 },
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
          ROUND(AVG(cm.branch_coverage), 2) AS value,
          CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END AS category
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE cm.branch_coverage IS NOT NULL
        AND %s
        AND CASE WHEN ${section:singlequote} = 'All' THEN true WHEN ${section:singlequote} = 'Uncategorized' THEN co.section IS NULL ELSE co.section = ${section:singlequote} END
        AND CASE WHEN ${stage:singlequote} = 'All' THEN true WHEN ${stage:singlequote} = 'Uncategorized' THEN co.stage IS NULL ELSE co.stage = ${stage:singlequote} END
        AND CASE WHEN ${group:singlequote} = 'All' THEN true WHEN ${group:singlequote} = 'Uncategorized' THEN co.group IS NULL ELSE co.group = ${group:singlequote} END
        AND CASE WHEN ${category:singlequote} = 'All' THEN true WHEN ${category:singlequote} = 'Uncategorized' THEN cm.category IS NULL ELSE cm.category = ${category:singlequote} END
        AND (${source_file_type:singlequote} = 'All' OR cm.source_file_type = ${source_file_type:singlequote})
      GROUP BY cm.timestamp, category
      ORDER BY time ASC
    ||| % [sql.timeRangeFilter('timestamp')],
    refId: 'A',
  }],
  title: 'Category Branch Coverage Trend',
  transformations: [{ id: 'prepareTimeSeries', options: { format: 'multi' } }],
  type: 'timeseries',
};

// Category Function Coverage Trend timeseries
local categoryFunctionCoverageTrend = {
  datasource: panels.clickHouseDatasource,
  description: 'Function coverage trend over time by category.',
  fieldConfig: {
    defaults: {
      color: { mode: 'palette-classic' },
      custom: {
        axisBorderShow: false,
        axisCenteredZero: false,
        axisColorMode: 'text',
        axisLabel: '',
        axisPlacement: 'auto',
        barAlignment: -1,
        barWidthFactor: 0.6,
        drawStyle: 'line',
        fillOpacity: 0,
        gradientMode: 'none',
        hideFrom: { legend: false, tooltip: false, viz: false },
        insertNulls: false,
        lineInterpolation: 'linear',
        lineStyle: { fill: 'solid' },
        lineWidth: 1,
        pointSize: 5,
        scaleDistribution: { type: 'linear' },
        showPoints: 'auto',
        showValues: false,
        spanNulls: false,
        stacking: { group: 'A', mode: 'none' },
        thresholdsStyle: { mode: 'off' },
      },
      displayName: '${__field.labels.category}',
      fieldMinMax: false,
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [{ color: 'green', value: 0 }],
      },
      unit: 'percent',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 8, x: 16, y: 21 },
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
          ROUND(AVG(cm.function_coverage), 2) AS value,
          CASE WHEN cm.category IS NULL OR cm.category = '' THEN 'null' ELSE cm.category END AS category
      FROM "code_coverage"."coverage_metrics" cm
      LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
      WHERE cm.function_coverage IS NOT NULL
        AND %s
        AND CASE WHEN ${section:singlequote} = 'All' THEN true WHEN ${section:singlequote} = 'Uncategorized' THEN co.section IS NULL ELSE co.section = ${section:singlequote} END
        AND CASE WHEN ${stage:singlequote} = 'All' THEN true WHEN ${stage:singlequote} = 'Uncategorized' THEN co.stage IS NULL ELSE co.stage = ${stage:singlequote} END
        AND CASE WHEN ${group:singlequote} = 'All' THEN true WHEN ${group:singlequote} = 'Uncategorized' THEN co.group IS NULL ELSE co.group = ${group:singlequote} END
        AND CASE WHEN ${category:singlequote} = 'All' THEN true WHEN ${category:singlequote} = 'Uncategorized' THEN cm.category IS NULL ELSE cm.category = ${category:singlequote} END
        AND (${source_file_type:singlequote} = 'All' OR cm.source_file_type = ${source_file_type:singlequote})
      GROUP BY cm.timestamp, category
      ORDER BY time ASC
    ||| % [sql.timeRangeFilter('timestamp')],
    refId: 'A',
  }],
  title: 'Category Function Coverage Trend',
  transformations: [{ id: 'prepareTimeSeries', options: { format: 'multi' } }],
  type: 'timeseries',
};

config.addStandardTemplates(
  basic.dashboard(
    'Coverage Trends',
    tags=config.codeCoverageTags,
    time_from='now-7d',
    time_to='now',
  )
  .addLink(config.backToHealthCheckLink)
)
.addTemplate(groupByTemplate)
.addPanels([
  aboutTextPanel,
  lineCoverageByProductLevel,
  branchCoverageByProductLevel,
  functionCoverageByProductLevel,
  categoryCoverageGainsTable,
  categoryCoverageDropsTable,
  categoryLineCoverageTrend,
  categoryBranchCoverageTrend,
  categoryFunctionCoverageTrend,
])
+ {
  templating+: {
    list: std.filter(
      function(t) t.name != 'PROMETHEUS_DS' && t.name != 'environment',
      super.list
    ),
  },
}
