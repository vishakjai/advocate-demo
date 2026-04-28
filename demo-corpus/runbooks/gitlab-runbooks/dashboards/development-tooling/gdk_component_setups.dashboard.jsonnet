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

local aiSetupTotalDurationQuery = |||
  SELECT
    time,
    round(quantileExact(0.9)(duration)) as p90,
    round(quantileExact(0.8)(duration)) as p80,
    round(quantileExact(0.5)(duration)) as p50,
    round(quantileExact(0.3)(duration)) as p30,
    round(avg(duration), 2) as avg_duration
  FROM
  (
      SELECT
        JSONExtractString(custom_event_props, 'session_id') as session_id,
        sum(JSONExtractFloat(custom_event_props, 'extras', 'duration_seconds')) as duration,
        date_trunc('week', any(collector_tstamp)) as time
      FROM
        default.events
      WHERE
        app_id = '$app_id'
        AND custom_event_name = 'Custom ai_setup_component'
        AND collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
        AND JSONExtractString(custom_event_props, 'extras', 'component') != ''
      GROUP BY session_id
      HAVING
        SUM(JSONExtractBool(custom_event_props, 'value')) = COUNT(*)
  )
  GROUP BY time
  ORDER BY time ASC
|||;

local aiSetupTotalSuccessRateQuery = |||
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
          custom_event_name like 'Finish rake%%setup_ai_development%%'
          or custom_event_name like 'Failed rake%%setup_ai_development%%'
        )
        AND collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
    )
  GROUP BY time
|||;

local aiSetupUniqueUsersQuery = |||
  SELECT
    date_trunc('week', collector_tstamp) as time,
    count(distinct user_id) as userCount
  FROM
    default.events
  WHERE
    app_id = '$app_id'
    AND custom_event_name = 'Custom ai_setup_component'
    AND collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
  GROUP BY time
  ORDER BY time ASC
|||;

local aiSetupReliabilityQuery = |||
  SELECT
    date_trunc('week', collector_tstamp) as time,
    JSONExtractString(custom_event_props, 'extras', 'component') as component,
    round(countIf(JSONExtractBool(custom_event_props, 'value') = 1) / count() * 100, 2) as success_rate
  FROM
    default.events
  WHERE
    app_id = '$app_id'
    AND custom_event_name = 'Custom ai_setup_component'
    AND collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
    AND JSONExtractString(custom_event_props, 'extras', 'component') != ''
  GROUP BY time, component
  ORDER BY time ASC
|||;

local aiSetupPerformanceQuery = |||
  SELECT
    date_trunc('week', collector_tstamp) as time,
    JSONExtractString(custom_event_props, 'extras', 'component') as component,
    round(avg(JSONExtractFloat(custom_event_props, 'extras', 'duration_seconds')), 2) as avg_duration
  FROM
    default.events
  WHERE
    app_id = '$app_id'
    AND custom_event_name = 'Custom ai_setup_component'
    AND collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
    AND JSONExtractBool(custom_event_props, 'value') = 1
    AND JSONExtractString(custom_event_props, 'extras', 'component') != ''
  GROUP BY time, component
  ORDER BY time ASC
|||;

local aiSetupFailureReasonsQuery = |||
  SELECT
    date_trunc('week', collector_tstamp) as time,
    concat(
      JSONExtractString(custom_event_props, 'extras', 'component'),
      ': ',
      COALESCE(
        nullif(JSONExtractString(custom_event_props, 'extras', 'error'), ''),
        'unknown_error'
      )
    ) as failure_source,
    count() as count
  FROM
    default.events
  WHERE
    app_id = '$app_id'
    AND custom_event_name = 'Custom ai_setup_component'
    AND collector_tstamp >= date_trunc('week', date_sub(now(), interval 14 week))
    AND JSONExtractBool(custom_event_props, 'value') = 0
  GROUP BY time, failure_source
  ORDER BY time ASC
|||;

local aiSetupRow(y) = layout.titleRowWithPanels(
  'AI Development Setup',
  [
    common.makeDurationPanel(aiSetupTotalDurationQuery) + {
      title: 'Duration: rake setup_ai_development',
      gridPos: { h: 8, w: 12, x: 0, y: 1 },
      fieldConfig+: {
        defaults+: {
          unit: 's',
          custom+: {
            drawStyle: 'line',
            lineWidth: 2,
            showPoints: 'auto',
          },
        },
      },
    },
    common.makeSuccessRatePanel(aiSetupTotalSuccessRateQuery) + {
      title: 'Success rate: rake setup_ai_development',
      gridPos: { h: 8, w: 12, x: 12, y: 1 },
    },
    common.makeDurationPanel(aiSetupPerformanceQuery) + {
      title: 'Average duration by component',
      gridPos: { h: 8, w: 12, x: 0, y: 9 },
      fieldConfig+: {
        defaults+: {
          unit: 's',
          custom+: {
            drawStyle: 'bars',
            fillOpacity: 80,
            gradientMode: 'none',
            stacking: {
              mode: 'normal',
              group: 'A',
            },
          },
        },
        overrides: [
          {
            matcher: { id: 'byRegexp', options: '.*' },
            properties: [{ id: 'displayName', value: '${__field.labels.component}' }],
          },
        ],
      },
    },
    common.makeDurationPanel(aiSetupReliabilityQuery) + {
      title: 'Success rate by component',
      gridPos: { h: 8, w: 12, x: 12, y: 9 },
      fieldConfig+: {
        defaults+: {
          unit: 'percent',
          max: 100,
          min: 0,
          custom+: {
            drawStyle: 'line',
            lineInterpolation: 'stepAfter',
            spanNulls: true,
            lineWidth: 2,
          },
        },
        overrides: [
          {
            matcher: { id: 'byRegexp', options: '.*' },
            properties: [{ id: 'displayName', value: '${__field.labels.component}' }],
          },
        ],
      },
    },
    common.makeDurationPanel(aiSetupUniqueUsersQuery) + {
      title: 'Unique user count',
      gridPos: { h: 8, w: 12, x: 0, y: 17 },
      fieldConfig+: {
        defaults+: {
          unit: 'users',
          color: { mode: 'palette-classic' },
          custom+: {
            drawStyle: 'bars',
            fillOpacity: 100,
            gradientMode: 'none',
          },
        },
      },
    },
    common.makeDurationPanel(aiSetupFailureReasonsQuery) + {
      title: 'Failure sources',
      gridPos: { h: 8, w: 12, x: 12, y: 17 },
      fieldConfig+: {
        defaults+: {
          unit: 'short',
          custom+: {
            drawStyle: 'bars',
            fillOpacity: 80,
            gradientMode: 'none',
            stacking: {
              mode: 'normal',
              group: 'A',
            },
          },
        },
        overrides: [
          {
            matcher: { id: 'byRegexp', options: '.*' },
            properties: [{ id: 'displayName', value: '${__field.labels.failure_source}' }],
          },
        ],
      },
      options+: {
        legend+: {
          displayMode: 'table',
          placement: 'right',
          showLegend: true,
          calcs: ['sum'],
        },
        tooltip+: {
          mode: 'multi',
          sort: 'desc',
        },
      },
    },
  ],
  true,
  y
);

local dashboard = basic.dashboard(
  'GDK Component Setups',
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
    aiSetupRow(1),
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
