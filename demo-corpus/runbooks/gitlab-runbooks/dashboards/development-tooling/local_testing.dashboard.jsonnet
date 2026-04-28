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
        (
          custom_event_name like 'Finish %%'
          or custom_event_name like 'Failed %%'
        )
        AND app_id = '$app_id'
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
        (
          custom_event_name like 'Finish %%'
          or custom_event_name like 'Failed %%'
        )
        AND app_id = '$app_id'
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

local numberOfExecutionsQuery = |||
  SELECT
    count(event_id) as predictiveRuns,
    date_trunc('week', collector_tstamp) as time
  FROM
    (
      SELECT
        collector_tstamp, event_id
      FROM
        default.events
      WHERE
        (
          custom_event_name like 'Finish %%'
          or custom_event_name like 'Failed %%'
        )
        AND app_id = '$app_id'
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

local localRspecRunsQuery = |||
  SELECT
  count(event_id) as LocalRSpecRuns, date_trunc('week', collector_tstamp) as time
  FROM
    default.events
  WHERE
    custom_event_name = 'Custom rspec_setup_duration'
    AND app_id = '$app_id'
    AND collector_tstamp >= date_trunc('week', date_add(WEEK, -14, now()))
  GROUP BY time
  ORDER BY time ASC
|||;

local rspecSetupDurationQuery = common.makeDurationQuery('rspec_setup_duration');

local rspecSetupDurationByStepQuery = common.makeDurationByStepQuery('rspec_setup_duration');

local makeDurationPanel(query) = {
  datasource: 'GitLab Development Kit ClickHouse',
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
        spanNulls: false,
        stacking: { group: 'A', mode: 'none' },
        thresholdsStyle: { mode: 'off' },
      },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'green' },
          { color: 'red', value: 80 },
        ],
      },
      unit: 's',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 12, x: 0, y: 2 },
  options: {
    legend: {
      calcs: [],
      displayMode: 'list',
      placement: 'bottom',
      showLegend: true,
    },
    tooltip: {
      hideZeros: false,
      mode: 'multi',
      sort: 'none',
    },
  },
  pluginVersion: '11.6.0-pre',
  targets: [{
    datasource: 'GitLab Development Kit ClickHouse',
    editorType: 'sql',
    format: 0,
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
    queryType: 'timeseries',
    rawSql: query,
    refId: 'A',
  }],
  title: 'Duration',
  type: 'timeseries',
};

local makeSuccessRatePanel(query) = {
  datasource: 'GitLab Development Kit ClickHouse',
  fieldConfig: {
    defaults: {
      color: { mode: 'palette-classic' },
      custom: {
        axisBorderShow: false,
        axisCenteredZero: false,
        axisColorMode: 'text',
        axisLabel: '',
        axisPlacement: 'auto',
        fillOpacity: 80,
        gradientMode: 'none',
        hideFrom: { legend: false, tooltip: false, viz: false },
        lineWidth: 1,
        scaleDistribution: { type: 'linear' },
        thresholdsStyle: { mode: 'line' },
      },
      displayName: 'Success rate',
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'green' },
          { color: 'red', value: 0.9 },
        ],
      },
      unit: 'percentunit',
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 12, x: 12, y: 2 },
  options: {
    barRadius: 0,
    barWidth: 0.97,
    fullHighlight: false,
    groupWidth: 0.7,
    legend: {
      calcs: [],
      displayMode: 'list',
      placement: 'bottom',
      showLegend: true,
    },
    orientation: 'auto',
    showValue: 'auto',
    stacking: 'none',
    tooltip: {
      hideZeros: false,
      mode: 'multi',
      sort: 'none',
    },
    xTickLabelRotation: 0,
    xTickLabelSpacing: 0,
  },
  pluginVersion: '11.6.0-pre',
  targets: [{
    datasource: 'GitLab Development Kit ClickHouse',
    editorType: 'sql',
    format: 0,
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
    queryType: 'timeseries',
    rawSql: query,
    refId: 'A',
  }],
  title: 'Success rate',
  type: 'barchart',
};

local makeCommandExecutionsPanel(query) = {
  datasource: 'GitLab Development Kit ClickHouse',
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
        spanNulls: false,
        stacking: { group: 'A', mode: 'none' },
        thresholdsStyle: { mode: 'off' },
      },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'green' },
          { color: 'red', value: 80 },
        ],
      },
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 12, x: 0, y: 2 },
  options: {
    legend: {
      calcs: [],
      displayMode: 'list',
      placement: 'bottom',
      showLegend: true,
    },
    tooltip: {
      hideZeros: false,
      mode: 'multi',
      sort: 'none',
    },
  },
  pluginVersion: '11.6.0-pre',
  targets: [{
    datasource: 'GitLab Development Kit ClickHouse',
    editorType: 'sql',
    format: 0,
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
    queryType: 'timeseries',
    rawSql: query,
    refId: 'A',
  }],
  title: 'Number of Executions',
  type: 'timeseries',
};

local makeLocalRSpecRunsPanel(query) = {
  datasource: 'GitLab Development Kit ClickHouse',
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
        spanNulls: false,
        stacking: { group: 'A', mode: 'none' },
        thresholdsStyle: { mode: 'off' },
      },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'green' },
          { color: 'red', value: 80 },
        ],
      },
    },
    overrides: [],
  },
  gridPos: { h: 8, w: 12, x: 0, y: 2 },
  options: {
    legend: {
      calcs: [],
      displayMode: 'list',
      placement: 'bottom',
      showLegend: true,
    },
    tooltip: {
      hideZeros: false,
      mode: 'multi',
      sort: 'none',
    },
  },
  pluginVersion: '11.6.0-pre',
  targets: [{
    datasource: 'GitLab Development Kit ClickHouse',
    editorType: 'sql',
    format: 0,
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
    queryType: 'timeseries',
    rawSql: query,
    refId: 'A',
  }],
  title: 'Local RSpec runs',
  type: 'timeseries',
};

local rspecSetupRow(y) = layout.titleRowWithPanels(
  'RSpec setup duration (gitlab-org/gitlab)',
  [
    common.makeDurationPanel(rspecSetupDurationQuery) + {
      title: 'RSpec setup duration',
      gridPos: { h: 8, w: 12, x: 0, y: 2 },
      fieldConfig+: {
        defaults+: { unit: 's' },
      },
    },
    common.makeDurationPanel(rspecSetupDurationByStepQuery) + {
      title: 'RSpec setup duration breakdown',
      gridPos: { h: 8, w: 12, x: 12, y: 2 },
      fieldConfig+: {
        defaults+: { unit: 's' },
      },
    },
  ],
  true,
  y
);

local commandRow(cmd) = layout.titleRowWithPanels(
  title='%s command' % [cmd],
  panels=[
    makeSuccessRatePanel(successRateQuery % { command: cmd }),
    makeDurationPanel(durationQuery % { command: cmd }),
    makeCommandExecutionsPanel(numberOfExecutionsQuery % { command: cmd }),
  ],
  collapse=true,
  startRow=1
);

local localRspecRunsRow(startRow) = layout.titleRowWithPanels(
  title='Local RSpec runs (gitlab-org/gitlab)',
  panels=[
    makeLocalRSpecRunsPanel(localRspecRunsQuery),
  ],
  collapse=true,
  startRow=startRow
);

local commands = [
  'predictive',
];

local dashboard = basic.dashboard(
  'Local Testing',
  tags=[],
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
                      commandRow(cmd)
                      for cmd in commands
                    ] + [localRspecRunsRow(std.length(commands) + 1)] +
                    [rspecSetupRow(std.length(commands) + 2)])
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
