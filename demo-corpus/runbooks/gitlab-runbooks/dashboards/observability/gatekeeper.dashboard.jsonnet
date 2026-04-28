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
  'Gatekeeper',
  tags=[
    'k8s',
    'gos',
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
  'label_values(kube_pod_container_info{env="$environment",cluster=~"opstrace-.*"}, cluster)',
  label='Cluster',
  refresh='load',
  sort=1,
))
.addTemplate(template.new(
  'gatekeeperPods',
  '$PROMETHEUS_DS',
  'label_values(kube_pod_container_info{env="$environment",cluster=~"opstrace-.*", container="gatekeeper"}, pod)',
  label='Gatekeeper pods',
  refresh='time',
  sort=1,
  multi=true,
  includeAll=true,
))
.addTemplate(
  template.custom(
    name='Deployment',
    query='gatekeeper,',
    current='gatekeeper',
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
  row.new(title='Gatekeeper version'),
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
.addPanels(k8sPodsCommon.memory(startRow=301, container='gatekeeper'))
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
  row.new(title='Login statistics'),
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
      panel.multiTimeSeries(
        title='Logins',
        queries=[
          {
            legendFormat: 'failures',
            query: 'sum(rate(login_failures{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
          },
          {
            legendFormat: 'starts',
            query: 'sum(rate(login_starts{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
          },
          {
            legendFormat: 'successes',
            query: 'sum(rate(login_successes{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
          },
        ],
        legend_show=true,
      ),
    ],
    cols=1,
    rowHeight=10,
    startRow=501,
  )
)
.addPanel(
  row.new(title='Cache'),
  gridPos={
    x: 0,
    y: 600,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.multiTimeSeries(
        title='Logins',
        queries=[
          {
            legendFormat: 'get - {{object_type}}',
            query: 'sum by(object_type) (rate(cache_gets{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
          },
          {
            legendFormat: 'hits',
            query: 'sum(rate(login_successes{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
          },
          {
            legendFormat: 'misses',
            query: 'sum (rate(cache_misses{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
          },
        ],
        legend_show=true,
      ),
      panel.timeSeries(
        title='Cache sets by type',
        query='sum by(object_type) (rate(cache_sets{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
        legendFormat='{{object_type}}',
      ),
      basic.heatmap(
        title='Redis GET time',
        query='sum by(le) (increase(cache_get_time_bucket{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
        dataFormat='tsbuckets',
        color_cardColor='#ff0000',
        legendFormat='__auto',
      ),
      basic.heatmap(
        title='Redis SET time',
        query='sum by(le) (increase(cache_set_time_bucket{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
        dataFormat='tsbuckets',
        color_cardColor='#ff0000',
        legendFormat='__auto',
      ),
      basic.heatmap(
        title='Redis Master PING time',
        query='sum by(le) (increase(master_ping_time_bucket{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
        dataFormat='tsbuckets',
        color_cardColor='#ff0000',
        legendFormat='__auto',
      ),
      panel.timeSeries(
        title='Redis Master failovers',
        query='sum (rate(master_failovers{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
        legendFormat='{{object_type}}',
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=601,
  )
)
.addPanel(
  row.new(title='HTTP'),
  gridPos={
    x: 0,
    y: 700,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Requests total',
        query='sum by(uri, method, code) (rate(gin_uri_request_total{env="$environment", cluster=~"$cluster", pod=~"$gatekeeperPods"}[$__rate_interval]))',
        legendFormat='{{method}} {{ uri }} - {{code}}',
        legend_rightSide=true,
      ),
    ],
    cols=1,
    rowHeight=10,
    startRow=701,
  )
)
