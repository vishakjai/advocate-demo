local common = import 'common.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local template = grafana.template;

local appMappings = [
  { id: 'e2e967c0-785f-40ae-9b45-5a05f729a27f', label: 'Production' },
  { id: '6a31192c-6567-40a3-9413-923abc790f05', label: 'CI' },
];

local appIdTemplateQuery = |||
  SELECT
    app_id as __value,
    CASE
      WHEN app_id = '%(production_id)s' THEN '%(production_label)s - %(production_id)s'
      WHEN app_id = '%(ci_id)s' THEN '%(ci_label)s - %(ci_id)s'
      ELSE app_id
    END as __text
  FROM (SELECT DISTINCT(app_id) FROM default.events)
  WHERE app_id IN ('%(production_id)s', '%(ci_id)s')
  ORDER BY
    CASE
      WHEN app_id = '%(production_id)s' THEN 1
      ELSE 2
    END, app_id
||| % {
  production_id: appMappings[0].id,
  production_label: appMappings[0].label,
  ci_id: appMappings[1].id,
  ci_label: appMappings[1].label,
};

local durationQuery = |||
  SELECT
    date_trunc('week', collector_tstamp) as time,
    round(quantileExact(0.9)(duration)) as p90,
    round(quantileExact(0.8)(duration)) as p80,
    round(quantileExact(0.5)(duration)) as p50,
    round(quantileExact(0.3)(duration)) as p30,
    round(avg(duration)) as avg
  FROM
    (
      SELECT
        collector_tstamp,
        visitParamExtractFloat(custom_event_props, 'duration') as duration
      FROM
        default.events
      WHERE
        app_id = '$app_id'
        AND (
          custom_event_name like 'Finish %%'
          or custom_event_name like 'Failed %%'
        )
        AND collector_tstamp >= date_trunc('week', date_add(WEEK, -14, now()))
        AND regexp_replace(
          custom_event_name,
          '(Finish|Failed) (rake [^ ]+|[^ ]+)?.*',
          '\\2'
        ) = '%(command)s'
    )
  GROUP BY time
  ORDER BY time ASC
|||;

local successRateQuery = |||
  SELECT
    date_trunc('week', collector_tstamp) as time,
    round(sum(success) / count(*), 3) as success_rate
  FROM
    (
      SELECT
        collector_tstamp,
        if(custom_event_name like 'Finish %%', 1.0, 0.0) as success
      FROM
        default.events
      WHERE
        app_id = '$app_id'
        AND (
          custom_event_name like 'Finish %%'
          or custom_event_name like 'Failed %%'
        )
        AND collector_tstamp >= date_trunc('week', date_add(WEEK, -14, now()))
        AND regexp_replace(
          custom_event_name,
          '(Finish|Failed) (rake [^ ]+|[^ ]+)?.*',
          '\\2'
        ) = '%(command)s'
    )
  GROUP BY time
|||;

local versionManagerQuery = |||
  SELECT
    date_trunc('week', collector_tstamp) as time,
    coalesce(
      nullif(
        JSONExtractString(custom_event_props, 'version_manager'),
        ''
      ),
      'notReported'
    ) as version_manager,
    count(distinct user_id) as userCount
  FROM
    default.events
  WHERE
    app_id = '$app_id'
    AND collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
  GROUP BY time, version_manager
  ORDER BY time ASC, userCount DESC;
|||;

local deviceTypesQuery = |||
  WITH total_count as (
    SELECT
      date_trunc('week', collector_tstamp) as time,
      count(*) as total_event_count
    FROM
      default.events
    WHERE
      collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
    GROUP BY 1
  ), platform_archs as (
    SELECT
      date_trunc('week', collector_tstamp) as time,
      visitParamExtractString (custom_event_props, 'platform') as platform,
      visitParamExtractString (custom_event_props, 'architecture') as architecture,
      count(*) as count
    FROM
      default.events
    WHERE
      app_id = '$app_id'
      AND collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
      AND platform != 'native'
    GROUP BY 1, 2, 3
    ORDER BY 1 ASC
  )
  SELECT
    time,
    concat(
      platform,
      if (
        length(architecture) > 0,
        concat('-', architecture),
        ''
      )
    ) as device_type,
    round(100 * sum(count) / max(total_event_count), 2) as rate
  FROM
    platform_archs
    join total_count on total_count.time = platform_archs.time
  GROUP BY time, 2
  ORDER BY 1 ASC
|||;

local updateFailureSources = |||
  WITH base AS (
    SELECT
      collector_tstamp,
      custom_event_name,
      REGEXP_REPLACE(
        custom_event_name,
        '(Finish|Failed) (rake [^ ]+|[^ ]+)?.*',
        '\\2'
      ) AS command_name,
      IF(custom_event_name LIKE 'Finish %', 1.0, 0.0) AS success
    FROM
      default.events
    WHERE
      app_id = '$app_id'
      AND (
        custom_event_name LIKE 'Finish %'
        OR custom_event_name LIKE 'Failed %'
      )
      AND collector_tstamp >= DATE_TRUNC('week', DATE_ADD(WEEK, -14, NOW()))
  )

  SELECT
    command_name,
    DATE_TRUNC('week', collector_tstamp) AS period,
    COUNT(*) - SUM(success) AS failure_count
  FROM
    base
  WHERE
    (
      command_name LIKE 'rake update:%'
      OR command_name IN (
        'rake preflight-update-checks',
        'rake preflight-checks',
        'rake gitlab-db-migrate'
      )
    )
  GROUP BY
    1, 2
  ORDER BY
    2 ASC, 1 ASC;
|||;

local reconfigureFailureSources = |||
  WITH base AS (
    SELECT
      collector_tstamp,
      custom_event_name,
      REGEXP_REPLACE(
        custom_event_name,
        '(Finish|Failed) (rake [^ ]+|[^ ]+)?.*',
        '\\2'
      ) AS command_name,
      IF(custom_event_name LIKE 'Finish %', 1.0, 0.0) AS success
    FROM
      default.events
    WHERE
      app_id = '$app_id'
      AND (
        custom_event_name LIKE 'Finish %'
        OR custom_event_name LIKE 'Failed %'
      )
      AND collector_tstamp >= DATE_TRUNC('week', DATE_ADD(WEEK, -14, NOW()))
  )

  SELECT
    command_name,
    DATE_TRUNC('week', collector_tstamp) AS period,
    COUNT(*) - SUM(success) AS failure_count
  FROM
    base
  WHERE
    (
      command_name LIKE 'rake reconfigure:%'
    )
  GROUP BY
    1, 2
  ORDER BY
    2 ASC, 1 ASC;
|||;

local eventsPerDayQuery = |||
  SELECT
    toDate(collector_tstamp) AS time,
    CASE
        WHEN splitByWhitespace(coalesce(custom_event_name, ''))[1] IN ('Finish', 'Failed')
            THEN splitByWhitespace(coalesce(custom_event_name, ''))[1]
        ELSE arrayStringConcat(arraySlice(splitByWhitespace(coalesce(custom_event_name, '')), 1, 2), ' ')
    END as name_type,
    count() AS event_count
  FROM
    default.events
  WHERE
    app_id = '$app_id'
    AND collector_tstamp >= date_sub(now(), interval 14 week)
  GROUP BY time, name_type
  ORDER BY time ASC, name_type
|||;

local dailyEventsRow(y) = layout.titleRowWithPanels(
  'Event Activity',
  [
    common.makeDurationPanel(eventsPerDayQuery) + {
      title: 'Events per Day by Type',
      gridPos: { h: 12, w: 24, x: 0, y: 1 },
      fieldConfig+: {
        defaults+: {
          unit: 'short',
          custom+: {
            drawStyle: 'line',
            lineInterpolation: 'linear',
            barAlignment: 0,
            lineWidth: 2,
            fillOpacity: 20,
            gradientMode: 'none',
            spanNulls: false,
            showPoints: 'never',
            pointSize: 5,
            stacking: {
              mode: 'normal',
              group: 'A',
            },
          },
        },
        overrides: [
          {
            matcher: { id: 'byRegexp', options: '.*' },
            properties: [
              {
                id: 'displayName',
                value: '${__field.labels.name_type}',
              },
            ],
          },
          {
            matcher: { id: 'byName', options: 'Finish' },
            properties: [
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'green',
                },
              },
            ],
          },
          {
            matcher: { id: 'byName', options: 'Failed' },
            properties: [
              {
                id: 'color',
                value: {
                  mode: 'fixed',
                  fixedColor: 'red',
                },
              },
            ],
          },
          {
            matcher: { id: 'byRegexp', options: 'Custom.*' },
            properties: [
              {
                id: 'color',
                value: {
                  mode: 'palette-classic',
                },
              },
            ],
          },
        ],
      },
      options+: {
        legend+: {
          displayMode: 'list',
          placement: 'bottom',
          showLegend: true,
          calcs: [],
        },
      },
    },
  ],
  false,
  y
);

local commandRow(cmd, y) = {
  collapsed: true,
  gridPos: { h: 1, w: 24, x: 0, y: y },
  title: cmd + ' command',
  type: 'row',
  panels: [
    common.makeDurationPanel(durationQuery % { command: cmd }),
    common.makeSuccessRatePanel(successRateQuery % { command: cmd }),
  ],
};

local commands = [
  'update',
  'reconfigure',
  'doctor',
  'cells',
  'cleanup',
  'diff-config',
  'install',
  'kill',
  'pristine',
  'report',
  'reset-data',
  'restart',
  'sandbox',
  'send-telemetry',
  'setup-workspace',
  'start',
  'status',
  'stop',
  'switch',
];

local hardwareDemographicsRow(y) = {
  collapsed: true,
  gridPos: { h: 1, w: 24, x: 0, y: y },
  title: 'Hardware demographics',
  type: 'row',
  panels: [
    common.makeDurationPanel(versionManagerQuery) + {
      title: 'Version manager',
      gridPos: { h: 8, w: 12, x: 0, y: 2 },
      fieldConfig+: {
        defaults+: { unit: 'short' },
        overrides+: [
          {
            matcher: { id: 'byRegexp', options: '.*' },
            properties: [
              {
                id: 'displayName',
                value: '${__field.labels.version_manager}',
              },
            ],
          },
        ],
      },
    },
    common.makeDurationPanel(deviceTypesQuery) + {
      title: 'Device types',
      gridPos: { h: 8, w: 12, x: 12, y: 2 },
      fieldConfig+: {
        defaults+: { unit: 'short' },
        overrides+: [
          {
            matcher: { id: 'byRegexp', options: '.*' },
            properties: [
              {
                id: 'displayName',
                value: '${__field.labels.device_type}',
              },
            ],
          },
        ],
      },
    },
  ],
};

local failureSourcesRow(title, query, y) = {
  collapsed: true,
  gridPos: { h: 1, w: 24, x: 0, y: y },
  title: title,
  type: 'row',
  panels: [
    common.makeDurationPanel(query) + {
      title: 'Failure sources',
      gridPos: { h: 12, w: 24, x: 0, y: 1 },
      fieldConfig+: {
        defaults+: {
          unit: 'short',
          custom+: {
            drawStyle: 'bars',
            barAlignment: 0,
            fillOpacity: 100,
            gradientMode: 'none',
            stacking: {
              mode: 'normal',
              group: 'A',
            },
          },
        },
        overrides+: [
          {
            matcher: { id: 'byRegexp', options: '.*' },
            properties: [
              {
                id: 'displayName',
                value: '${__field.labels.command_name}',
              },
            ],
          },
        ],
      },
      options+: {
        tooltip+: {
          mode: 'multi',
          sort: 'desc',
        },
        legend+: {
          displayMode: 'list',
          placement: 'bottom',
          showLegend: true,
          calcs: [],
        },
      },
    },
  ],
};

local environmentCommands = ['cleanup', 'pristine', 'reset-data', 'kill'];
local managingCommands = ['update', 'restart', 'start', 'status', 'stop'];
local settingCommands = ['diff-config', 'config'];
local setupCommands = ['install', 'reconfigure'];
local toolCommands = ['console', 'help', 'predictive', 'sandbox', 'switch'];
local troubleshootingCommands = ['doctor', 'report'];
local allCommands = {
  'Environment Commands': environmentCommands,
  'Managing Commands': managingCommands,
  'Setup Commands': setupCommands,
  'Setting Commands': settingCommands,
  'Tool Commands': toolCommands,
  'Troubleshooting Commands': troubleshootingCommands,
};

local generateTarget(command) = {
  datasource: 'GitLab Development Kit ClickHouse',
  refId: std.asciiUpper(command[0]) + command[1:],  // capitalize first letter
  hide: false,
  editorType: 'sql',
  queryType: 'timeseries',
  rawSql: successRateQuery % { command: command },
  format: 0,
  meta: {
    builderOptions: {
      database: '',
      table: '',
      queryType: 'table',
      columns: [],
      mode: 'list',
      limit: 1000,
    },
  },
  pluginVersion: '4.11.2',
};

local overviewPanel(commandList, xPos) = {
  id: 76,
  type: 'table',
  title: '',
  gridPos: { x: 0, y: 0, h: 8, w: 12 },
  fieldConfig: {
    defaults: {
      custom: {
        align: 'auto',
        footer: {
          reducers: [],
        },
        cellOptions: {
          type: 'auto',
        },
        inspect: false,
      },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'green' },
          { color: 'red', value: 0.9 },
        ],
      },
      color: { mode: 'palette-classic' },
    },
    overrides: [],
  },
  transformations: [
    {
      id: 'joinByField',
      options: {},
    },
    {
      id: 'timeSeriesTable',
      options: {
        joinByField: {
          timeField: 'time',
        },
      },
    },
    {
      id: 'organize',
      options: {
        excludeByName: {},
        indexByName: {},
        renameByName: {
          name: 'Command',
        },
        includeByName: {},
      },
    },
    {
      id: 'renameByRegex',
      options: {
        regex: 'Trend #joinByField.*',
        renamePattern: 'Success rate',
      },
    },
  ],
  pluginVersion: '12.3.0',
  targets: [generateTarget(command) for command in commandList],
  options: {
    showHeader: true,
    cellHeight: 'sm',
    frameIndex: 0,
    enablePagination: false,
    sortBy: [
      {
        displayName: 'Trends',
        desc: true,
      },
    ],
  },
};

local overviewRow(y, i) = {
  collapsed: true,
  gridPos: { h: 1, w: 24, x: 0, y: y },
  title: '%s overview' % std.objectFields(allCommands)[i],
  type: 'row',
  panels: [
    overviewPanel(allCommands[std.objectFields(allCommands)[i]], i),
  ],
};

local dashboard = basic.dashboard(
  'GDK Commands',
  tags=['gdk'],
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource='GitLab Development Kit ClickHouse'
).addTemplate(template.new(
  'app_id',
  'GitLab Development Kit ClickHouse',
  appIdTemplateQuery,
  label='App ID',
  current=appMappings[0].id,
  sort=true
)).addPanels(
  std.flattenArrays([
    dailyEventsRow(0),
    [overviewRow(i + 1, i) for i in std.range(0, std.length(allCommands) - 1)],
    [commandRow(commands[i], i + 6) for i in std.range(0, std.length(commands) - 1)],
    [hardwareDemographicsRow(std.length(commands) + 6)],
    [failureSourcesRow('Monthly failure sources', updateFailureSources, std.length(commands) + 7)],
    [failureSourcesRow('Reconfigure failure sources', reconfigureFailureSources, std.length(commands) + 8)],
  ])
) + {
  time: {
    from: 'now-14w',
    to: 'now',
  },
  refresh: '1h',
};

// Override to remove all template variables
(dashboard {
   templating+: {
     list: std.filter(
       function(template) template.name != 'PROMETHEUS_DS',
       super.list
     ),
   },
 }).trailer()
