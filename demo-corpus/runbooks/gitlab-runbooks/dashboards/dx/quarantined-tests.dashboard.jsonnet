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

// SQL table constants
local quarantinedTestsHourlyMv = 'test_metrics.quarantined_tests_hourly_mv';
local testFileRiskSummary = 'code_coverage.test_file_risk_summary';
local hourTimestampRangeFilter = sql.timeRangeFilter('hour_timestamp');

// Template variables - these are multi-select with time-range filtering
local sectionTemplate = template.new(
  'section',
  datasource,
  'SELECT DISTINCT section\n' +
  'FROM ' + quarantinedTestsHourlyMv + '\n' +
  'WHERE ' + hourTimestampRangeFilter + '\n' +
  "  AND section != ''\n" +
  'ORDER BY section',
  refresh='time',
  includeAll=true,
  allValues="'All'",
  multi=true,
);

local stageTemplate = template.new(
  'stage',
  datasource,
  'SELECT DISTINCT stage\n' +
  'FROM ' + quarantinedTestsHourlyMv + '\n' +
  'WHERE ' + hourTimestampRangeFilter + '\n' +
  "  AND (${section:singlequote} = 'All' OR (${section:singlequote} = 'Uncategorized' AND section IS NULL) OR section IN (${section:singlequote}))\n" +
  "  AND stage != ''\n" +
  'ORDER BY stage',
  refresh='time',
  includeAll=true,
  allValues="'All'",
  multi=true,
);

local groupTemplate = template.new(
  'group',
  datasource,
  'SELECT DISTINCT group\n' +
  'FROM ' + quarantinedTestsHourlyMv + '\n' +
  'WHERE ' + hourTimestampRangeFilter + '\n' +
  "  AND (${section:singlequote} = 'All' OR (${section:singlequote} = 'Uncategorized' AND section IS NULL) OR section IN (${section:singlequote}))\n" +
  "  AND (${stage:singlequote} = 'All' OR (${stage:singlequote} = 'Uncategorized' AND stage IS NULL) OR stage IN (${stage:singlequote}))\n" +
  "  AND group != ''\n" +
  'ORDER BY group',
  refresh='time',
  includeAll=true,
  allValues="'All'",
  multi=true,
  sort=1,
);

local featureCategoryTemplate = template.new(
  'feature_category',
  datasource,
  'SELECT DISTINCT feature_category\n' +
  'FROM ' + quarantinedTestsHourlyMv + '\n' +
  'WHERE ' + hourTimestampRangeFilter + '\n' +
  "  AND (${section:singlequote} = 'All' OR (${section:singlequote} = 'Uncategorized' AND section IS NULL) OR section IN (${section:singlequote}))\n" +
  "  AND (${stage:singlequote} = 'All' OR (${stage:singlequote} = 'Uncategorized' AND stage IS NULL) OR stage IN (${stage:singlequote}))\n" +
  "  AND (${group:singlequote} = 'All' OR (${group:singlequote} = 'Uncategorized' AND `group` IS NULL) OR `group` IN (${group:singlequote}))\n" +
  "  AND feature_category != ''\n" +
  'ORDER BY feature_category',
  refresh='time',
  includeAll=true,
  allValues="'All'",
  multi=true,
  sort=1,
);

local pipelineTypeTemplate = template.new(
  'pipeline_type',
  datasource,
  'SELECT DISTINCT pipeline_type\n' +
  'FROM ' + quarantinedTestsHourlyMv + '\n' +
  'WHERE ' + hourTimestampRangeFilter + '\n' +
  '  AND run_type IN (${run_type:singlequote})\n' +
  "  AND pipeline_type != ''\n" +
  'ORDER BY pipeline_type',
  refresh='load',
  includeAll=true,
  multi=true,
);

local runTypeTemplate = template.new(
  'run_type',
  datasource,
  'SELECT DISTINCT run_type\n' +
  'FROM ' + quarantinedTestsHourlyMv + '\n' +
  'WHERE ' + hourTimestampRangeFilter + '\n' +
  "  AND run_type != ''\n" +
  'ORDER BY run_type',
  refresh='load',
  includeAll=true,
  multi=true,
);

local projectPathTemplate = template.new(
  'project_path',
  datasource,
  'SELECT DISTINCT project_path\n' +
  'FROM ' + quarantinedTestsHourlyMv + '\n' +
  'WHERE ' + hourTimestampRangeFilter + '\n' +
  "  AND project_path != ''\n" +
  'ORDER BY project_path',
  refresh='load',
  includeAll=true,
  multi=true,
);

// Total Quarantined Tests stat panel
local totalQuarantinedStat = {
  datasource: { type: 'grafana-clickhouse-datasource', uid: datasourceUid },
  description: 'Total unique quarantined tests based on last 12 hours',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'green', value: 0 },
          { color: 'yellow', value: 50 },
          { color: 'red', value: 100 },
        ],
      },
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 6, x: 0, y: 0 },
  options: {
    colorMode: 'value',
    graphMode: 'area',
    justifyMode: 'auto',
    orientation: 'auto',
    percentChangeColorMode: 'standard',
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    showPercentChange: false,
    textMode: 'auto',
    wideLayout: true,
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    meta: {},
    pluginVersion: '4.12.0',
    queryType: 'table',
    rawSql: 'SELECT\n' +
            '  uniq(file_path, location) as total_quarantined\n' +
            'FROM ' + quarantinedTestsHourlyMv + '\n' +
            'WHERE hour_timestamp >= now() - INTERVAL 12 HOUR \n' +
            '  AND hour_timestamp <= now()\n' +
            "  AND (${section:singlequote} = 'All' OR (${section:singlequote} = 'Uncategorized' AND section IS NULL) OR section IN (${section:singlequote}))\n" +
            "  AND (${stage:singlequote} = 'All' OR (${stage:singlequote} = 'Uncategorized' AND stage IS NULL) OR stage IN (${stage:singlequote}))\n" +
            "  AND (${group:singlequote} = 'All' OR (${group:singlequote} = 'Uncategorized' AND `group` IS NULL) OR `group` IN (${group:singlequote}))\n" +
            "  AND (${feature_category:singlequote} = 'All' OR (${feature_category:singlequote} = 'Uncategorized' AND feature_category IS NULL) OR feature_category IN (${feature_category:singlequote}))\n" +
            '  AND run_type IN (${run_type:singlequote})\n' +
            '  AND project_path IN (${project_path:singlequote})\n' +
            '  AND pipeline_type IN (${pipeline_type:singlequote})',
    refId: 'A',
  }],
  title: 'Total Quarantined Tests - Last 12h',
  type: 'stat',
};

// Quarantined Tests Over Time timeseries
local quarantinedOverTimeTimeseries = {
  datasource: { type: 'grafana-clickhouse-datasource', uid: datasourceUid },
  description: 'Quarantined test count over time',
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
        lineInterpolation: 'smooth',
        lineWidth: 2,
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
        steps: [{ color: 'green', value: 0 }],
      },
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 18, x: 6, y: 0 },
  options: {
    legend: { calcs: ['max'], displayMode: 'table', placement: 'right', showLegend: true },
    tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 0,
    meta: {},
    pluginVersion: '4.12.0',
    queryType: 'timeseries',
    rawSql: 'SELECT\n' +
            '  toStartOfDay(hour_timestamp) as time,\n' +
            '  uniq(file_path, location) as quarantined_tests\n' +
            'FROM ' + quarantinedTestsHourlyMv + '\n' +
            'WHERE ' + hourTimestampRangeFilter + '\n' +
            "  AND (${section:singlequote} = 'All' OR (${section:singlequote} = 'Uncategorized' AND section IS NULL) OR section IN (${section:singlequote}))\n" +
            "  AND (${stage:singlequote} = 'All' OR (${stage:singlequote} = 'Uncategorized' AND stage IS NULL) OR stage IN (${stage:singlequote}))\n" +
            "  AND (${group:singlequote} = 'All' OR (${group:singlequote} = 'Uncategorized' AND `group` IS NULL) OR `group` IN (${group:singlequote}))\n" +
            "  AND (${feature_category:singlequote} = 'All' OR (${feature_category:singlequote} = 'Uncategorized' AND feature_category IS NULL) OR feature_category IN (${feature_category:singlequote}))\n" +
            '  AND run_type IN (${run_type:singlequote})\n' +
            '  AND project_path IN (${project_path:singlequote})\n' +
            '  AND pipeline_type IN (${pipeline_type:singlequote})\n' +
            'GROUP BY time\n' +
            'ORDER BY time',
    refId: 'A',
  }],
  title: 'Quarantined Tests Over Time',
  type: 'timeseries',
};

// Risk Level Legend text panel
local riskLevelLegend = {
  fieldConfig: { defaults: {}, overrides: [] },
  gridPos: { h: 13, w: 6, x: 18, y: 8 },
  options: {
    code: { language: 'plaintext', showLineNumbers: false, showMiniMap: false },
    content: '**Risk Levels:**\n\nShows the highest risk level across all source files this test covers, based on what fraction of each file\'s total test coverage this test represents.\n\n- <span style="color:#F2495C">**CRITICAL**</span> ≥ 50% — this test covers more than half of a source file\'s total test coverage\n- <span style="color:#FF9830">**HIGH**</span> 20–50%\n- <span style="color:#FADE2A">**MEDIUM**</span> 5–20%\n- <span style="color:#73BF69">**LOW**</span> < 5%\n- **UNKNOWN** — no coverage mapping data available for this test',
    mode: 'markdown',
  },
  pluginVersion: '12.3.1',
  title: '',
  transparent: true,
  type: 'text',
};

// Quarantined Tests List table
local quarantinedTestsListTable = {
  datasource: { type: 'grafana-clickhouse-datasource', uid: datasourceUid },
  description: 'List of quarantined tests by project and run type with details. Number of rows is high as a test can be quarantined for multiple projects and run types',
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      custom: {
        align: 'auto',
        cellOptions: { type: 'auto' },
        filterable: true,
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
      {
        matcher: { id: 'byName', options: 'file_path' },
        properties: [{ id: 'custom.width', value: 350 }],
      },
      panels.riskLevelOverride(100),
      {
        matcher: { id: 'byName', options: 'location' },
        properties: [
          { id: 'custom.width', value: 300 },
          {
            id: 'links',
            value: [{
              targetBlank: true,
              title: '${__value.raw}',
              url: 'https://gitlab.com/gitlab-org/gitlab/-/blob/master/${__data.fields.spec_file_path_prefix}${__data.fields.file_path}${__data.fields.line_anchor}',
            }],
          },
        ],
      },
      {
        matcher: { id: 'byName', options: 'times_seen' },
        properties: [{ id: 'custom.width', value: 137 }],
      },
      {
        matcher: { id: 'byName', options: 'last_seen' },
        properties: [{ id: 'custom.width', value: 150 }],
      },
      {
        matcher: { id: 'byName', options: 'feature_category' },
        properties: [{ id: 'custom.width', value: 241 }],
      },
      {
        matcher: { id: 'byName', options: 'first_seen' },
        properties: [{ id: 'custom.width', value: 210 }],
      },
      {
        matcher: { id: 'byName', options: 'spec_file_path_prefix' },
        properties: [{ id: 'custom.hidden', value: true }],
      },
    ],
  },
  gridPos: { h: 13, w: 18, x: 0, y: 8 },
  options: {
    cellHeight: 'sm',
    enablePagination: true,
    showHeader: true,
    sortBy: [{ desc: false, displayName: 'section' }],
  },
  pluginVersion: '12.3.1',
  targets: [{
    editorType: 'sql',
    format: 1,
    meta: {},
    pluginVersion: '4.12.0',
    queryType: 'table',
    rawSql: 'SELECT\n' +
            '  file_path,\n' +
            '  COALESCE(any(r.risk_level), \'UNKNOWN\') as "Risk Level",\n' +
            '  location,\n' +
            '  project_path,\n' +
            '  run_type,\n' +
            '  "group",\n' +
            '  stage,\n' +
            '  section,\n' +
            '  feature_category,\n' +
            '  sum(times_seen) as times_seen,\n' +
            '  sum(pipeline_count) as pipeline_count,\n' +
            '  min(hour_timestamp) as first_seen,\n' +
            '  max(hour_timestamp) as last_seen,\n' +
            "  concat('#L', extractAll(location, ':(\\d+)')[1]) as line_anchor,\n" +
            '  any(spec_file_path_prefix) as spec_file_path_prefix\n' +
            'FROM ' + quarantinedTestsHourlyMv + ' q\n' +
            'LEFT JOIN ' + testFileRiskSummary + ' r FINAL\n' +
            '  ON q.file_path = r.test_file\n' +
            '  AND r.ci_project_path IN (${project_path:singlequote})\n' +
            'WHERE ' + hourTimestampRangeFilter + '\n' +
            "  AND (${section:singlequote} = 'All' OR (${section:singlequote} = 'Uncategorized' AND section IS NULL) OR section IN (${section:singlequote}))\n" +
            "  AND (${stage:singlequote} = 'All' OR (${stage:singlequote} = 'Uncategorized' AND stage IS NULL) OR stage IN (${stage:singlequote}))\n" +
            "  AND (${group:singlequote} = 'All' OR (${group:singlequote} = 'Uncategorized' AND \"group\" IS NULL) OR \"group\" IN (${group:singlequote}))\n" +
            "  AND (${feature_category:singlequote} = 'All' OR (${feature_category:singlequote} = 'Uncategorized' AND feature_category IS NULL) OR feature_category IN (${feature_category:singlequote}))\n" +
            '  AND run_type IN (${run_type:singlequote})\n' +
            '  AND project_path IN (${project_path:singlequote})\n' +
            '  AND pipeline_type IN (${pipeline_type:singlequote})\n' +
            'GROUP BY file_path, location, run_type, project_path, "group", stage, section, feature_category\n' +
            'ORDER BY CASE "Risk Level" WHEN \'CRITICAL\' THEN 1 WHEN \'HIGH\' THEN 2 WHEN \'MEDIUM\' THEN 3 WHEN \'LOW\' THEN 4 ELSE 5 END ASC, times_seen DESC',
    refId: 'A',
  }],
  title: 'Quarantined Tests List',
  type: 'table',
};

basic.dashboard(
  'Quarantined Tests',
  tags=['quarantine'] + config.testMetricsTags,
  time_from='now-30d',
  time_to='now',
)
.addTemplates([
  sectionTemplate,
  stageTemplate,
  groupTemplate,
  featureCategoryTemplate,
  runTypeTemplate,
  projectPathTemplate,
  pipelineTypeTemplate,
])
.addPanels([
  totalQuarantinedStat,
  quarantinedOverTimeTimeseries,
  quarantinedTestsListTable,
  riskLevelLegend,
])
+ {
  description: 'Track quarantined tests over time with section/stage/group filtering',
  refresh: '15m',
  templating+: {
    list: std.filter(
      function(t) t.name != 'PROMETHEUS_DS' && t.name != 'environment',
      super.list
    ),
  },
}
