local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local k8sPodsCommon = import 'gitlab-dashboards/kubernetes_pods_common.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local selectors = import 'promql/selectors.libsonnet';
local nodeSelector = {
  env: '$environment',
  cluster: '$cluster',
};
local nodeSelectorSerialized = selectors.serializeHash(nodeSelector);
local etSelector = nodeSelector { namespace: 'default' };
local etSelectorSerialized = selectors.serializeHash(etSelector);

local generalGraphPanel(
  title,
  fill=0,
  format=null,
  formatY1=null,
  formatY2=null,
  decimals=3,
  description=null,
  linewidth=2,
  sort=0,
      ) =
  panel.basic(
    title,
    linewidth=linewidth,
    unit=format,
    datasource='$PROMETHEUS_DS',
    description=description,
    legend_min=false,
    legend_avg=false,
    legend_rightSide=true,
    legend_hideEmpty=false,
  );

basic.dashboard(
  'Errortracking API',
  tags=[
    'gitlab-observability',
  ],
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-observability')
)
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
.addTemplate(
  template.custom(
    name='namespace',
    label='Environment',
    query='default',
    current='default',
    hide='variable',
  )
)
.addTemplate(
  template.custom(
    name='Node',
    label='Node',
    query='gke-',
    current='gke-',
    hide='variable',
  )
)
.addTemplate(
  template.custom(
    name='Deployment',
    query='errortracking',
    current='errortracking',
    hide='variable',
  )
)
.addPanel(
  row.new(title='Deployed version(s)'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Active version',
        query=|||
          count(
              kube_pod_container_info{%(selector)s, pod=~"errortracking-api.*"}
          ) by (image)
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{ image }}',
      ),
      panel.timeSeries(
        title='Up',
        query=|||
          up{%(selector)s, job="errortracking-api", endpoint="metrics"}
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{ instance }}',
      ),
      panel.timeSeries(
        title='Ready replicas',
        query=|||
          kube_statefulset_status_replicas_ready{%(selector)s, statefulset="errortracking-api"}
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{ statefulset }}',
      ),
    ],
    cols=3,
    rowHeight=10,
    startRow=1,
  )
)
.addPanel(
  row.new(title='Deployment Info'),
  gridPos={ x: 0, y: 100, w: 24, h: 1 }
)
.addPanels(
  layout.grid([
    basic.gaugePanel(
      'Deployment CPU Usage',
      query=|||
        100 *
        sum(
          rate(
            container_cpu_usage_seconds_total{%(selector)s, pod=~"errortracking-api.*"}[2m]
          )
        )
        /
        sum(machine_cpu_cores{%(selector)s, node=~"gke-.*"})
      ||| % { selector: nodeSelectorSerialized },
      instant=false,
      unit='percentunit',
      max=1,
      color=[
        { color: 'green', value: null },
        { color: 'orange', value: 0.65 },
        { color: 'red', value: 0.90 },
      ],
    ),
    basic.gaugePanel(
      'Deployment Memory Usage',
      query=|||
        100 *
        sum(container_memory_working_set_bytes{%(selector)s, pod=~"errortracking-api.*"})
        /
        sum(kube_node_status_allocatable{resource="memory", unit= "byte", env=~"$environment", node=~"gke-.*"})
      ||| % { selector: etSelectorSerialized },
      instant=false,
      unit='percent',
      color=[
        { color: 'green', value: null },
        { color: 'orange', value: 65 },
        { color: 'red', value: 90 },
      ],
    ),
  ], cols=2, rowHeight=5, startRow=101)
)
.addPanel(
  row.new(title='CPU'),
  gridPos={ x: 0, y: 200, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      generalGraphPanel(
        'Usage',
        format='none',
      )
      .addTarget(
        target.prometheus(
          |||
            sum(
              rate(
                container_cpu_usage_seconds_total{%(selector)s, pod=~"errortracking-api.*"}[1m]
              )
            ) by (pod,node)
          ||| % { selector: etSelectorSerialized },
          legendFormat='real: {{ pod }}',
        )
      )
      .addTarget(
        target.prometheus(
          |||
            sum(
              kube_pod_container_resource_requests{%(selector)s, resource="cpu", unit="core", pod=~"errortracking-api.*"}
            ) by (pod,node)
          ||| % { selector: etSelectorSerialized },
          legendFormat='rqst: {{ pod }}',
        )
      )
      .addYaxis(label='cores'),
    ],
    cols=1,
    rowHeight=10,
    startRow=201,
  )
)
.addPanel(
  row.new(title='Memory'),
  gridPos={ x: 0, y: 300, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      generalGraphPanel('Usage', format='bytes')
      .addTarget(
        target.prometheus(
          |||
            sum(
              container_memory_working_set_bytes{%(selector)s, pod=~"errortracking-api.*", container="errortracking-api"}
            ) by (pod)
          ||| % { selector: etSelectorSerialized },
          legendFormat='real: {{ pod }}',
        )
      ),
    ],
    cols=1,
    rowHeight=10,
    startRow=301,
  )
)
.addPanel(
  row.new(title='Network'),
  gridPos={ x: 0, y: 400, w: 24, h: 1 }
)
.addPanels(k8sPodsCommon.network(startRow=401))
.addPanels(k8sPodsCommon.network(startRow=401))
.addPanel(
  row.new(title='Requests'),
  gridPos={ x: 0, y: 500, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Requests per second by HTTP status',
        query=|||
          sum(
            rate(
              http_requests_duration_seconds_count{%(selector)s, pod=~"errortracking-api.*"}[$__rate_interval]
            )
          ) by (code) > 0
        ||| % { selector: etSelectorSerialized },
        legendFormat='HTTP {{code}}',
        yAxisLabel='req/sec',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.multiQuantileTimeSeries(
        title='Requests duration by HTTP status',
        selector='env="$environment", cluster=~"$cluster", pod=~"errortracking-api.*"',
        legendFormat='HTTP {{code}}',
        bucketMetric='http_requests_duration_seconds_bucket',
        aggregators='code',
        legend_rightSide=true,
      ),
      panel.timeSeries(
        title='Requests per second by path',
        query=|||
          sum(
            rate(
              http_requests_duration_seconds_count{%(selector)s, pod=~"errortracking-api.*"}[$__rate_interval]
            )
          ) by (path) > 0
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{path}}',
        yAxisLabel='req/sec',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.multiQuantileTimeSeries(
        title='Requests duration by path',
        selector='env="$environment", cluster=~"$cluster", pod=~"errortracking-api.*"',
        legendFormat='{{path}}',
        bucketMetric='http_requests_duration_seconds_bucket',
        aggregators='path',
        legend_rightSide=true,
      ),
      panel.timeSeries(
        title='Response Error Rate by Method and Path',
        query=|||
          sum by (method, path) (
            rate(
              http_requests_duration_seconds_count{%(selector)s, pod=~"errortracking-api.*", code =~ "[4-5].*"}[$__rate_interval]
            )
          )
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{ method }} {{ path }}',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=601,
  )
)
.addPanel(
  row.new(title='Project-specific telemetry'),
  gridPos={ x: 0, y: 700, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Envelope requests by project ID',
        query=|||
          sum(
            rate(
              project_envelope_total{%(selector)s, pod=~"errortracking-api.*"}[$__rate_interval]
            )
          ) by (projectID)
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{projectID}}',
        yAxisLabel='req/sec',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.timeSeries(
        title='Get error requests by project ID',
        query=|||
          sum(
            rate(
              project_get_error_total{%(selector)s, pod=~"errortracking-api.*"}[$__rate_interval]
            )
          ) by (projectID)
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{projectID}}',
        yAxisLabel='req/sec',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.timeSeries(
        title='List errors requests by project ID',
        query=|||
          sum(
            rate(
              project_list_errors_total{%(selector)s, pod=~"errortracking-api.*"}[$__rate_interval]
            )
          ) by (projectID)
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{projectID}}',
        yAxisLabel='req/sec',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.timeSeries(
        title='List events requests by project ID',
        query=|||
          sum(
            rate(
              project_list_events_total{%(selector)s, pod=~"errortracking-api.*"}[$__rate_interval]
            )
          ) by (projectID)
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{projectID}}',
        yAxisLabel='req/sec',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
      panel.timeSeries(
        title='Store requests by project ID',
        query=|||
          sum(
            rate(
              project_store_total{%(selector)s, pod=~"errortracking-api.*"}[$__rate_interval]
            )
          ) by (projectID)
        ||| % { selector: etSelectorSerialized },
        legendFormat='{{projectID}}',
        yAxisLabel='req/sec',
        fill=50,
        legend_rightSide=true,
        stack=true,
      ),
    ],
    cols=3,
    rowHeight=10,
    startRow=701,
  )
)
