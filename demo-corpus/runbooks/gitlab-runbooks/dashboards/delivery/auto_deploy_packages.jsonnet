local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local prometheus = grafana.prometheus;
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local annotation = grafana.annotation;
local row = grafana.row;
local statPanel = grafana.statPanel;

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
  annotation.datasource(
    'Staging PDM',
    '-- Grafana --',
    enable=false,
    iconColor='#73BF69',
    tags=['pdm', 'gstg'],
  ),
  annotation.datasource(
    'Production PDM',
    '-- Grafana --',
    enable=false,
    iconColor='#FF9830',
    tags=['pdm', 'gprd'],
  ),
];

basic.dashboard(
  'Auto-Deploy packages information',
  tags=['release'],
  editable=true,
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource='mimir-gitlab-ops',
  time_from='now-14d'
)
.addAnnotations(annotations)

.addPanel(
  panel.basic(
    '📦 Number of packages tagged per day',
    description='Number of packages tagged per day.',
    unit='none',
  )
  .addTarget(
    prometheus.target(
      'sum(increase(delivery_packages_tagging_total{pkg_type="auto_deploy"}[1d])) by (pkg_type)',
      legendFormat='Tagged packages',
    ),
  )
  .addTarget(
    prometheus.target(
      |||
        sum(increase(delivery_deployment_started_total{target_env="gprd"}[1d]))
      |||, legendFormat='Promoted'
    )
  )
  .addTarget(
    prometheus.target(
      'sum(increase(delivery_auto_deploy_picks_total[1h])) by (status)',
      legendFormat='Pick into Auto-Deploy - {{status}}',
    ),
  ),
  gridPos={ x: 0, y: 0, w: 24, h: 10 }
)
.addPanel(
  panel.basic(
    'Active coordinated pipelines',
    description='Number of deployments pipelines that are running, scheduled, or manual',
    stack=true,
  )
  .addTarget(
    prometheus.target(
      'max(delivery_deployment_pipelines_total{status=~"scheduled|running|manual|failed"}) by (status)',
      legendFormat='{{status}}',
    ),
  ),
  gridPos={ x: 0, y: 100, w: 24, h: 12 }
)

.addPanel(
  panel.basic(
    '🚀 Number of deployments started per day',
    description='Number of deployments started per day.',
    unit='none',
  )
  .addTarget(
    prometheus.target(
      'sum(increase(delivery_deployment_started_total{target_env!="gstg-ref"}[1d])) by (target_env)',
      legendFormat='{{target_env}}',
    ),
  ),
  gridPos={ x: 0, y: 200, w: 24, h: 12 }
)
.trailer()
