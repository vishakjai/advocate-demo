local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local template = grafana.template;

// App ID for Caproni users - defined in:
// https://gitlab.com/gitlab-org/quality/tooling/gdk-telemetry-ingest-ruby/-/blob/main/config/app.yml
local caproniAppId = 'ca9654da-ba0e-489c-ba2a-f81990c2f826';

// Caproni events use two schemas:
//   new (most): {"meta":{"team_member":bool},"payload":{"name":"caproni <cmd>","args":[],"duration_ms":N}}
//   old (early): {"name":"<cmd>","args":[],"duration_ms":N,"error":null}
local cmdName = |||
  COALESCE(
    nullif(JSONExtractString(custom_event_props, 'payload', 'name'), ''),
    nullif(JSONExtractString(custom_event_props, 'name'), '')
  )
|||;

local durationMs = |||
  COALESCE(
    nullif(JSONExtractFloat(custom_event_props, 'payload', 'duration_ms'), 0),
    JSONExtractFloat(custom_event_props, 'duration_ms')
  )
|||;

// Appended to every WHERE clause - filters by team_member dropdown.
// Old-schema events (no 'meta' key) are excluded when a specific value is selected.
local teamMemberClause = |||
  AND (
    '${team_member}' = 'All'
    OR JSONExtractBool(custom_event_props, 'meta', 'team_member') = ('${team_member}' = 'true')
  )
|||;

// Shared interpolation args used by every query - extend with (theta { cmd: cmd }) for per-command queries.
local theta = { app_id: caproniAppId, cmd_name: cmdName, duration_ms: durationMs, tmc: teamMemberClause };

// ── Stat queries ─────────────────────────────────────────────────────────────

local totalEventsQuery = |||
  SELECT count() AS total_events
  FROM default.events
  WHERE app_id = '%(app_id)s'
    AND toYear(collector_tstamp) >= toYear(now()) - 1
    %(tmc)s
||| % theta;

local totalUsersQuery = |||
  SELECT count(distinct user_id) AS unique_users
  FROM default.events
  WHERE app_id = '%(app_id)s'
    AND toYear(collector_tstamp) >= toYear(now()) - 1
    %(tmc)s
||| % theta;

// ── Activity queries ──────────────────────────────────────────────────────────

local eventsPerDayByCommandQuery = |||
  SELECT
    toDate(collector_tstamp) AS time,
    %(cmd_name)s AS command_name,
    count() AS event_count
  FROM default.events
  WHERE app_id = '%(app_id)s'
    AND $__timeFilter(collector_tstamp)
    AND %(cmd_name)s != ''
    %(tmc)s
  GROUP BY time, command_name
  ORDER BY time ASC, event_count DESC
||| % theta;

local uniqueUsersPerDayQuery = |||
  SELECT
    toDate(collector_tstamp) AS time,
    count(distinct user_id) AS unique_users
  FROM default.events
  WHERE app_id = '%(app_id)s'
    AND $__timeFilter(collector_tstamp)
    %(tmc)s
  GROUP BY time
  ORDER BY time ASC
||| % theta;

// ── Per-command queries ───────────────────────────────────────────────────────

local commandDurationQuery(cmd) = |||
  SELECT
    toDate(collector_tstamp) AS time,
    round(quantileExact(0.5)(%(duration_ms)s) / 1000, 1) AS p50,
    round(quantileExact(0.9)(%(duration_ms)s) / 1000, 1) AS p90,
    round(avg(%(duration_ms)s) / 1000, 1) AS avg
  FROM default.events
  WHERE app_id = '%(app_id)s'
    AND $__timeFilter(collector_tstamp)
    AND %(cmd_name)s = '%(cmd)s'
    AND %(duration_ms)s > 0
    %(tmc)s
  GROUP BY time
  ORDER BY time ASC
||| % (theta { cmd: cmd });

local commandExecutionsQuery(cmd) = |||
  SELECT
    toDate(collector_tstamp) AS time,
    count() AS executions,
    count(distinct user_id) AS unique_users
  FROM default.events
  WHERE app_id = '%(app_id)s'
    AND $__timeFilter(collector_tstamp)
    AND %(cmd_name)s = '%(cmd)s'
    %(tmc)s
  GROUP BY time
  ORDER BY time ASC
||| % (theta { cmd: cmd });

// ── Panel helpers ─────────────────────────────────────────────────────────────

local datasource = 'GitLab Development Kit ClickHouse';

local baseTarget(query, queryType='timeseries') = {
  datasource: datasource,
  editorType: 'sql',
  format: if queryType == 'table' then 1 else 0,
  meta: {
    builderOptions: {
      columns: [],
      database: '',
      limit: 1000,
      mode: 'list',
      queryType: 'table',
      table: '',
    },
  },
  pluginVersion: '4.8.2',
  queryType: queryType,
  rawSql: query,
  refId: 'A',
};

local statPanel(title, query, x=0, w=6) = {
  datasource: datasource,
  type: 'stat',
  title: title,
  gridPos: { h: 2, w: w, x: x, y: 0 },
  targets: [baseTarget(query, 'table')],
  fieldConfig: {
    defaults: {
      color: { mode: 'thresholds' },
      thresholds: { mode: 'absolute', steps: [{ color: 'blue', value: null }] },
    },
    overrides: [],
  },
  options: {
    reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
    orientation: 'auto',
    textMode: 'auto',
    colorMode: 'background',
    graphMode: 'none',
    justifyMode: 'auto',
  },
};

local timeseriesPanel(title, query, gridPos, unit='short', stacked=false) = {
  datasource: datasource,
  type: 'timeseries',
  title: title,
  gridPos: gridPos,
  targets: [baseTarget(query)],
  fieldConfig: {
    defaults: {
      color: { mode: 'palette-classic' },
      unit: unit,
      custom: {
        drawStyle: 'line',
        lineInterpolation: 'linear',
        lineWidth: 2,
        fillOpacity: if stacked then 20 else 0,
        gradientMode: 'none',
        showPoints: 'never',
        spanNulls: false,
        stacking: if stacked then { mode: 'normal', group: 'A' } else { mode: 'none', group: 'A' },
      },
    },
    overrides: [],
  },
  options: {
    legend: { displayMode: 'list', placement: 'bottom', showLegend: true, calcs: [] },
    tooltip: { mode: 'multi', sort: 'desc' },
  },
};

local barChartPanel(title, query, gridPos) = {
  datasource: datasource,
  type: 'timeseries',
  title: title,
  gridPos: gridPos,
  targets: [baseTarget(query)],
  fieldConfig: {
    defaults: {
      color: { mode: 'palette-classic' },
      custom: {
        drawStyle: 'bars',
        fillOpacity: 100,
        gradientMode: 'none',
        stacking: { mode: 'normal', group: 'A' },
        lineWidth: 1,
        showPoints: 'never',
        spanNulls: false,
      },
    },
    overrides: [],
  },
  options: {
    legend: { displayMode: 'list', placement: 'bottom', showLegend: true, calcs: [] },
    tooltip: { mode: 'multi', sort: 'desc' },
  },
};

// Collapsed row with duration (left) + executions (right) charts.
local commandRow(cmd, y) = {
  collapsed: true,
  gridPos: { h: 1, w: 24, x: 0, y: y },
  title: cmd,
  type: 'row',
  panels: [
    timeseriesPanel(
      'Duration: ' + cmd,
      commandDurationQuery(cmd),
      { h: 8, w: 12, x: 0, y: y + 1 },
      unit='s'
    ),
    barChartPanel(
      'Executions: ' + cmd,
      commandExecutionsQuery(cmd),
      { h: 8, w: 12, x: 12, y: y + 1 }
    ),
  ],
};

// ── Commands list ─────────────────────────────────────────────────────────────

local commands = [
  'caproni run',
  'caproni up',
  'caproni down',
  'caproni edit-mode-process-supervisor',
  'caproni destroy',
  'caproni update',
  'caproni update-etc-hosts',
  'caproni status',
  'caproni config validate',
  'caproni sandbox create',
  'caproni sandbox run',
  'caproni sandbox delete',
  'caproni sandbox list',
  'caproni sandbox url',
  'caproni version',
];

// ── Layout ────────────────────────────────────────────────────────────────────

local overviewPanels = [
  statPanel('Total events', totalEventsQuery, x=0, w=8),
  statPanel('Total unique users', totalUsersQuery, x=8, w=8),

  timeseriesPanel(
    'Events per day by command',
    eventsPerDayByCommandQuery,
    { h: 10, w: 24, x: 0, y: 2 },
    stacked=true
  ) + {
    fieldConfig+: {
      overrides: [{
        matcher: { id: 'byRegexp', options: '.*' },
        properties: [{ id: 'displayName', value: '${__field.labels.command_name}' }],
      }],
    },
  },

  timeseriesPanel(
    'Unique users per day',
    uniqueUsersPerDayQuery,
    { h: 4, w: 24, x: 0, y: 12 }
  ),
];

// y=16: stats (h=2) + events chart (h=10) + users chart (h=4) = 16 overview rows.
local commandRowY(i) = 16 + i;

local dashboard = basic.dashboard(
  'Caproni',
  tags=['caproni'],
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=datasource
).addTemplate(template.custom(
  'team_member',
  'All,true,false',
  'All',
  label='Team member',
)).addPanels(
  overviewPanels +
  std.map(
    function(i) commandRow(commands[i], commandRowY(i)),
    std.range(0, std.length(commands) - 1)
  )
) + {
  time: { from: 'now-2w', to: 'now' },
  refresh: '1h',
};

(dashboard {
   templating+: {
     list: std.filter(
       function(t) t.name != 'PROMETHEUS_DS',
       super.list
     ),
   },
 }).trailer()
