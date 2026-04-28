local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local timepickerlib = import 'github.com/grafana/grafonnet-lib/grafonnet/timepicker.libsonnet';
local prometheus = grafana.prometheus;
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local annotation = grafana.annotation;
local row = grafana.row;
local statPanel = grafana.statPanel;
local panel = import 'grafana/time-series/panel.libsonnet';

local environments = [
  {
    id: 'gprd',
    name: 'Production',
    role: 'gprd',
    stage: 'main',
    icon: '🚀',
  },
  {
    id: 'gstg',
    name: 'Staging',
    role: 'gstg',
    stage: 'main',
    icon: '🏗',
  },
];

local annotations = [
  annotation.datasource(
    'Production deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#19730E',
    tags=['deploy', 'gprd'],
  ),
  annotation.datasource(
    'Canary deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#E08400',
    tags=['deploy', 'gprd-cny'],
  ),
  annotation.datasource(
    'Staging deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#5794F2',
    tags=['deploy', 'gstg'],
  ),
  annotation.datasource(
    'Staging Canary deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#8F3BB8',
    tags=['deploy', 'gstg-cny'],
  ),
];

local canRollback(environment) =
  prometheus.target(
    |||
      sum(
        increase(
          delivery_deployment_can_rollback_total{target_env="%(env)s"}[$__range]
        )
      ) /
      sum(
        increase(
          delivery_deployment_started_total{target_env="%(env)s"}[$__range]
        )
      )
    ||| % { env: environment.role },
    instant=true,
    format='time_series',
  );

local numberOfRollbacks(environment) =
  prometheus.target(
    |||
      sum(
        increase(
          delivery_deployment_rollbacks_started_total{target_env="%(env)s"}[$__range]
        )
      )
    ||| % { env: environment.role },
    instant=true,
    format='time_series',
  );

basic.dashboard(
  'Rollback information',
  tags=['release'],
  editable=true,
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  time_from='now-30d',
  defaultDatasource='mimir-gitlab-ops',
)
.addAnnotations(annotations)

.addPanel(
  row.new(title='Percentage of rollbackable packages'),
  gridPos={ x: 0, y: 0, w: 24, h: 8 },
)
.addPanels(
  layout.splitColumnGrid([
    // Column 1: Single stats of rollbackable package percentages
    [
      statPanel.new(
        title='%s %s' % [environment.icon, environment.id],
        description='Percentage of packages deployed to %s over the selected time range that could have been rolled back.' % [environment.name],
        unit='percentunit',
        thresholdsMode='percentage',
      )
      .addTarget(canRollback(environment))
      .addThresholds([
        {
          color: 'red',
          value: 0,
        },
        {
          value: 50,
          color: '#EAB839',
        },
        {
          color: 'green',
          value: 80,
        },
      ])
      for environment in environments
    ],
    // Column 2: Graph of rollbackable package percentages
    [
      panel.basic(
        'Percentage of deployments that could be rolled back per day',
        description='Percentage of deployments that could have been rolled back per day.',
        unit='percentunit',
      )
      .addYaxis(
        min=0,
        max=1,
        label='Percentage',
      )
      .addTarget(
        prometheus.target(
          |||
            sum(
              increase(
                delivery_deployment_can_rollback_total{target_env=~"%(env)s"}[1d]
              )
            ) by (target_env)
            /
            sum(
              increase(
                delivery_deployment_started_total{target_env=~"%(env)s"}[1d]
              )
            ) by (target_env)
          ||| % { env: std.join('|', [env.role for env in environments]) },
          legendFormat='{{target_env}}',
        ),
      ),
    ],
  ], cellHeights=[4 for x in environments], startRow=1)
)

// Row 2: Number of rollbacks performed in each env
.addPanel(
  row.new(title='Number of rollbacks performed'),
  gridPos={ x: 0, y: 1000, w: 24, h: 8 },
)
.addPanels(
  layout.splitColumnGrid([
    // Column 1: Single stats of number of rollbacks performed
    [
      statPanel.new(
        title='%s %s' % [environment.icon, environment.id],
        description='Number of rollbacks performed in %s over the selected time range.' % [environment.name],
      )
      .addTarget(numberOfRollbacks(environment))
      for environment in environments
    ],
    // Column 2: Graph of number of rollbacks performed
    [
      panel.basic(
        'Number of rollbacks',
        description='Number of rollbacks performed per day.',
      )
      .addTarget(
        prometheus.target(
          |||
            sum(
              increase(
                delivery_deployment_rollbacks_started_total{target_env=~"%(env)s"}[$__range]
              )
            ) by (target_env)
          ||| % { env: std.join('|', [env.role for env in environments]) },
          legendFormat='{{target_env}}',
        ),
      ),
    ],
  ], cellHeights=[4 for x in environments], startRow=1000)
)
