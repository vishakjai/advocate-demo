local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local k8sPodsCommon = import 'gitlab-dashboards/kubernetes_pods_common.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Ingress',
  tags=[
    'k8s',
    'gitlab-observability',
  ],
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-observability')
)
.addTemplate(templates.Node)
.addTemplate(
  template.custom(
    name='environment',
    label='Environment',
    query='gstg,gprd',
    current='gprd',
  )
)
.addTemplate(template.new(
  'cluster',
  '$PROMETHEUS_DS',
  'label_values(kube_pod_container_info{env="$environment", cluster=~"opstrace-.*"}, cluster)',
  label='Cluster',
  refresh='load',
  sort=1,
))
.addTemplate(template.new(
  'pods',
  '$PROMETHEUS_DS',
  'label_values(kube_pod_container_info{env="$environment", cluster=~"opstrace-.*", container="traefik"}, pod)',
  label='Traefik pods',
  refresh='time',
  sort=1,
  multi=true,
  includeAll=true,
))
.addTemplate(
  template.custom(
    name='Deployment',
    query='traefik',
    current='traefik',
    hide='variable',
  )
)
.addTemplate(
  template.custom(
    name='namespace',
    query='default,',
    current='default',
    hide='variable',
  )
)
.addPanel(
  row.new(title='Traefik version'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.version(startRow=1))
.addPanel(
  row.new(title='Deployment Info'),
  gridPos={
    x: 0,
    y: 100,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.deployment(startRow=101))
.addPanels(k8sPodsCommon.status(startRow=102))
.addPanel(
  row.new(title='CPU'),
  gridPos={
    x: 0,
    y: 200,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.cpu(startRow=201))
.addPanel(
  row.new(title='Memory'),
  gridPos={
    x: 0,
    y: 300,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.memory(startRow=301, container='traefik'))
.addPanel(
  row.new(title='Network'),
  gridPos={
    x: 0,
    y: 400,
    w: 24,
    h: 1,
  }
)
.addPanels(k8sPodsCommon.network(startRow=401))
.addPanel(
  row.new(title='Request Handling Performance'),
  gridPos={
    x: 0,
    y: 500,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Requests per second by HTTP status',
        query=|||
          sum(
            rate(
              traefik_service_requests_total{env="$environment", cluster=~"$cluster", pod=~"$pods"}[$__rate_interval]
            )
          ) by (code) > 0
        |||,
        legendFormat='HTTP {{code}}',
        yAxisLabel='rps',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.multiQuantileTimeSeries(
        title='Requests duration by HTTP status',
        selector='env="$environment", cluster=~"$cluster", pod=~"$pods"',
        legendFormat='HTTP {{code}}',
        bucketMetric='traefik_service_request_duration_seconds_bucket',
        aggregators='code',
        legend_rightSide=true,
      ),
      panel.timeSeries(
        title='Requests per second by Service',
        query=|||
          sum(
            rate(
              traefik_service_requests_total{env="$environment", cluster=~"$cluster", pod=~"$pods"}[$__rate_interval]
            )
          ) by (service) > 0
        |||,
        legendFormat='{{service}}',
        yAxisLabel='rps',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.multiQuantileTimeSeries(
        title='Requests duration by Service',
        selector='env="$environment", cluster=~"$cluster", pod=~"$pods"',
        legendFormat='{{service}}',
        bucketMetric='traefik_service_request_duration_seconds_bucket',
        aggregators='service',
        legend_rightSide=true,
      ),
      panel.timeSeries(
        title='Open Connections per Service',
        query=|||
          sum(
            rate(
              traefik_service_open_connections{env="$environment", cluster=~"$cluster", pod=~"$pods"}[$__rate_interval]
            )
          ) by (service) > 0
        |||,
        legendFormat='{{service}}',
        yAxisLabel='conn/sec',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.timeSeries(
        title='Error Rate by Service',
        query=|||
          sum(
            rate(
              traefik_service_requests_total{env="$environment", cluster=~"$cluster", pod=~"$pods", code =~ "[4-5].*"}[$__rate_interval]
            )
          ) by (method, service, code) > 0
        |||,
        legendFormat='{{ method }} {{ service }} {{code}}',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
    ],
    cols=1,
    rowHeight=10,
    startRow=601,
  )
)
