local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prometheus = grafana.prometheus;
local graphPanel = grafana.graphPanel;
local templates = import 'grafana/templates.libsonnet';
local template = grafana.template;
local promQuery = import 'grafana/prom_query.libsonnet';
local colorScheme = import 'grafana/color_scheme.libsonnet';
local pipelineOverview = import './panels/pipelineoverview.libjsonnet';
local row = grafana.row;

local explainer = |||
  This dashboard shows information about each particular deployment.

|||;

local bargaugePanel(
  title,
  description='',
  fieldLinks=[],
  format='time_series',
  instant=true,
  legendFormat='',
  links=[],
  mode='thresholds',
  orientation='vertical',
  query='',
  reduceOptions={
    calcs: [
      'last',
    ],
  },
  thresholds={},
  transformations=[],
  unit='s',
      ) =
  {
    description: description,
    fieldConfig: {
      values: false,
      defaults: {
        links: fieldLinks,
        mode: mode,
        thresholds: thresholds,
        unit: unit,
      },
    },
    links: links,
    options: {
      displayMode: 'basic',
      orientation: orientation,
      reduceOptions: reduceOptions,
      showUnfilled: true,
    },
    pluginVersion: '9.3.6',
    targets: [promQuery.target(query, format=format, legendFormat=legendFormat, instant=instant)],
    title: title,
    type: 'bargauge',
    transformations: transformations,
  };


basic.dashboard(
  'deployment-metrics',
  tags=[],
  editable=true,
  time_from='now-1d',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource='mimir-gitlab-ops',
)
.addTemplate(
  template.new(
    'deploy_version',
    '$PROMETHEUS_DS',
    'label_values(delivery_deployment_merge_request_lead_time_seconds, deploy_version)',
    label='version',
    refresh='time',
    sort=2,
  )
)
.addPanel(
  row.new(title='MTTP'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.columnGrid([
    [
      basic.statPanel(
        title='',
        panelTitle='MTTP over selected time range',
        color='blue',
        query='avg(\n                last_over_time(delivery_deployment_merge_request_lead_time_seconds{target_env="gprd", target_stage="main"}[$__range])\n                  unless\n                (\n                  last_over_time(\n                    delivery_deployment_merge_request_lead_time_seconds{target_env="gprd", target_stage="main"}[12h] offset $__range\n                  )\n                )\n              )',
        legendFormat='__auto',
        colorMode='background',
        textMode='value',
        unit='s',
        decimals=2,
      )
      .addThresholds([
        { color: colorScheme.normalRangeColor, value: 0 },
        { color: colorScheme.warningColor, value: 39600 },
        { color: colorScheme.errorColor, value: 43200 },
        { color: colorScheme.criticalColor, value: 46800 },
      ]),
      basic.statPanel(
        title='',
        panelTitle='Adjusted MTTP over selected time range',
        description='MTTP over selected time range when ignoring weekends. If the adjusted metric is not available, it\n                    will use the regular (unadjusted) metric. The adjusted metric is available from 7th Aug 2023 onwards.',
        color='blue',
        query='avg(\n                (\n                  last_over_time(delivery_deployment_merge_request_adjusted_lead_time_seconds{target_env="gprd", target_stage="main"}[$__range])\n                    or\n                  last_over_time(delivery_deployment_merge_request_lead_time_seconds{target_env="gprd", target_stage="main"}[$__range])\n                )\n                  unless\n                (\n                  last_over_time(delivery_deployment_merge_request_adjusted_lead_time_seconds{target_env="gprd", target_stage="main"}[12h] offset $__range)\n                    or\n                  last_over_time(delivery_deployment_merge_request_lead_time_seconds{target_env="gprd", target_stage="main"}[12h] offset $__range)\n                )\n              )',
        legendFormat='__auto',
        colorMode='background',
        textMode='value',
        unit='s',
        decimals=2,
      )
      .addThresholds([
        { color: colorScheme.normalRangeColor, value: 0 },
        { color: colorScheme.warningColor, value: 39600 },
        { color: colorScheme.errorColor, value: 43200 },
        { color: colorScheme.criticalColor, value: 46800 },
      ]),
    ],
  ], [5, 5], rowHeight=10, startRow=1)
)
.addPanel(
  row.new(title='🚀 Downstream Pipeline statistics'),
  gridPos={
    x: 0,
    y: 11,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.columnGrid([
    [
      bargaugePanel(
        'Downstream Pipelines Duration',
        description='Duration for each downstream pipelines to complete',
        instant=false,
        format='table',
        mode='absolute',
        legendFormat='{{target_env, target_stage}}',
        query='sum by (target_env, target_stage) (delivery_deployment_pipeline_duration_seconds{target_env!="",target_stage!="", deploy_version="$deploy_version", pipeline_name!="Coordinator pipeline"})',
        reduceOptions={
          values: true,
          calcs: [],
          fields: '',
        },
        thresholds={
          steps: [
            { color: colorScheme.normalRangeColor, value: 0 },
            { color: colorScheme.warningColor, value: 8400 },  // 140 minutes
            { color: colorScheme.errorColor, value: 10800 },  // 3 hours
            { color: colorScheme.criticalColor, value: 21600 },  // 6 hours
          ],
        },
        transformations=[
          {
            id: 'groupBy',
            options: {
              fields: {
                target_env: {
                  aggregations: [],
                  operation: 'groupby',
                },
                target_stage: {
                  aggregations: [],
                  operation: 'groupby',
                },
                Value: {
                  aggregations: [
                    'lastNotNull',
                  ],
                  operation: 'aggregate',
                },
              },
            },
          },
        ],
      ),
      basic.statPanel(
        color='blue',
        graphMode='area',
        instant=false,
        interval='',
        format='table',
        legendFormat='__auto',
        panelTitle='Coordinated Pipeline Duration',
        query='delivery_deployment_pipeline_duration_seconds{project_name="gitlab-org/release/tools", pipeline_name="Coordinator pipeline", deploy_version="$deploy_version"}',
        title='',
        transformations=[
          {
            id: 'groupBy',
            options: {
              fields: {
                Value: {
                  aggregations: [
                    'last',
                  ],
                  operation: 'aggregate',
                },
                deploy_version: {
                  aggregations: [],
                  operation: 'groupby',
                },
              },
            },
          },
        ],
        unit='s',
      )
      .addThresholds([
        { color: colorScheme.normalRangeColor, value: 0 },
        { color: colorScheme.warningColor, value: 28800 },
        { color: colorScheme.errorColor, value: 36000 },
        { color: colorScheme.criticalColor, value: 43200 },
      ]),
    ],
    [pipelineOverview],
  ], [19, 5], rowHeight=10, startRow=12)
)

.addPanel(
  row.new(title='📊 Merge requests statistics'),
  gridPos={
    x: 0,
    y: 22,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.columnGrid([
    [
      bargaugePanel(
        'Merge requests lead time to production',
        description='Time it take Merge Request from being merged to production',
        query='last_over_time(delivery_deployment_merge_request_lead_time_seconds{target_env="gprd", target_stage="main", deploy_version="$deploy_version"}[$__range])',
        legendFormat='{{mr_id}}',
        fieldLinks=[
          {
            title: 'View merge request',
            url: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/${__field.labels.mr_id}',
            targetBlank: true,
          },
        ],
        thresholds={
          steps: [
            { color: colorScheme.normalRangeColor, value: 0 },
            { color: colorScheme.warningColor, value: 39600 },
            { color: colorScheme.errorColor, value: 43200 },
            { color: colorScheme.criticalColor, value: 46800 },
          ],
        },
      ),
      basic.statPanel(
        title='',
        panelTitle='Average MR lead time to production for selected version',
        color='blue',
        query='avg(last_over_time(delivery_deployment_merge_request_lead_time_seconds{target_env="gprd", target_stage="main", deploy_version="$deploy_version"}[$__range]))',
        legendFormat='__auto',
        colorMode='background',
        textMode='value',
        unit='s',
        decimals=2,
      )
      .addThresholds([
        { color: colorScheme.normalRangeColor, value: 0 },
        { color: colorScheme.warningColor, value: 39600 },
        { color: colorScheme.errorColor, value: 43200 },
        { color: colorScheme.criticalColor, value: 46800 },
      ]),
    ],
  ], [19, 5], rowHeight=10, startRow=24)
)
.addPanels(
  layout.columnGrid([
    [
      bargaugePanel(
        'Adjusted merge requests lead time to production',
        description='Time it takes merge requests from being merged to production, adjusted to ignore weekends',
        query='last_over_time(delivery_deployment_merge_request_adjusted_lead_time_seconds{target_env="gprd", target_stage="main", deploy_version="$deploy_version"}[$__range])',
        legendFormat='{{mr_id}}',
        fieldLinks=[
          {
            title: 'View merge request',
            url: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/${__field.labels.mr_id}',
            targetBlank: true,
          },
        ],
        thresholds={
          steps: [
            { color: colorScheme.normalRangeColor, value: 0 },
            { color: colorScheme.warningColor, value: 39600 },
            { color: colorScheme.errorColor, value: 43200 },
            { color: colorScheme.criticalColor, value: 46800 },
          ],
        },
      ),
      basic.statPanel(
        title='',
        panelTitle='Average adjusted MR lead time to production for selected version',
        color='blue',
        query='avg(last_over_time(delivery_deployment_merge_request_adjusted_lead_time_seconds{target_env="gprd", target_stage="main", deploy_version="$deploy_version"}[$__range]))',
        legendFormat='__auto',
        colorMode='background',
        textMode='value',
        unit='s',
        decimals=2,
      )
      .addThresholds([
        { color: colorScheme.normalRangeColor, value: 0 },
        { color: colorScheme.warningColor, value: 39600 },
        { color: colorScheme.errorColor, value: 43200 },
        { color: colorScheme.criticalColor, value: 46800 },
      ]),
    ],
  ], [19, 5], rowHeight=10, startRow=24)
)

.trailer()
