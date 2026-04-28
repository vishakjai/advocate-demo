local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local collectorSelector = {
  env: '$environment',
  cluster: '$cluster',
  namespace: '$namespace',
  container: 'otel-collector',
};
local collectorSelectorSerialized = selectors.serializeHash(collectorSelector);
local queryAPISelector = {
  env: '$environment',
  cluster: '$cluster',
  namespace: 'default',
  container: 'trace-query-api',
};
local queryAPISelectorSerialized = selectors.serializeHash(queryAPISelector);

basic.dashboard(
  'Tracing',
  tags=[
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
.addTemplate(
  template.new(
    'cluster',
    '$PROMETHEUS_DS',
    'label_values(kube_pod_container_info{env="$environment", cluster=~"opstrace-.*"}, cluster)',
    label='Cluster',
    refresh='load',
    sort=1,
  )
)
.addTemplate(
  template.new(
    'namespace',
    '$PROMETHEUS_DS',
    'label_values(kube_namespace_labels{namespace=~"tenant-.*"}, namespace)',
    label='Namespace',
    refresh='time',
    multi=false,
    includeAll=false,
  )
)
.addPanel(
  row.new(title='Deployment Status'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Active Version - otel-collector',
        query=|||
          count(
            kube_pod_container_info{%(selector)s}
          ) by (image)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ image }}',
      ),
      panel.timeSeries(
        title='Up - otel-collector/metrics',
        query=|||
          up{%(selector)s, job="otel-collector", endpoint="metrics"}
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Process uptime - otel-collector',
        query=|||
          otelcol_process_uptime{%(selector)s}
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Query API uptime',
        query=|||
          up{%(selector)s, endpoint="metrics"}
        ||| % { selector: queryAPISelectorSerialized },
        legendFormat='{{ container }}',
      ),
    ],
    cols=4,
    rowHeight=8,
    startRow=1,
  )
)
.addPanel(
  row.new(title='HTTP Receiver'),
  gridPos={ x: 0, y: 100, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Accepted Spans',
        query=|||
          sum (
            rate(otelcol_receiver_accepted_spans{%(selector)s}[1m])
          ) by (namespace)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Refused Spans',
        query=|||
          sum (
            rate(otelcol_receiver_refused_spans{%(selector)s}[1m])
          ) by (namespace)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
    ],
    cols=2,
    rowHeight=8,
    startRow=101,
  )
)
.addPanel(
  row.new(title='ClickHouse Exporter'),
  gridPos={ x: 0, y: 200, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Spans Received',
        query=|||
          sum (
            rate(custom_spans_received{%(selector)s}[1m])
          ) by (namespace)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Spans Ingested',
        query=|||
          sum (
            rate(custom_spans_ingested{%(selector)s}[1m])
          ) by (namespace)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Traces Total Bytes',
        query=|||
          sum (
            rate(custom_traces_size_bytes{%(selector)s}[1m])
          ) by (namespace)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
    ],
    cols=3,
    rowHeight=8,
    startRow=201,
  )
)
.addPanel(
  row.new(title='Resource Utilisation'),
  gridPos={ x: 0, y: 300, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='CPU - otel-collector (millicores)',
        query=|||
          sum(
            rate(container_cpu_usage_seconds_total{%(selector)s}[2m])
          ) by (namespace) * 1000
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Memory Usage (max) - otel-collector (GBs)',
        query=|||
          max(container_memory_working_set_bytes{%(selector)s}) / (1024*1024*1024)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='CPU - trace-query-api (millicores)',
        query=|||
          sum(
            rate(container_cpu_usage_seconds_total{%(selector)s}[2m])
          ) * 1000
        ||| % { selector: queryAPISelectorSerialized },
        legendFormat='{{ container }}',
      ),
      panel.timeSeries(
        title='Memory Usage (max) - trace-query-api (GBs)',
        query=|||
          max(container_memory_working_set_bytes{%(selector)s}) / (1024*1024*1024)
        ||| % { selector: queryAPISelectorSerialized },
        legendFormat='{{ container }}'
      ),
    ],
    cols=4,
    rowHeight=8,
    startRow=301,
  )
)
.addPanel(
  row.new(title='Pipeline Scalability'),
  gridPos={ x: 0, y: 400, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Memory-Limiter Refused Spans',
        query=|||
          sum (
            rate(otelcol_processor_refused_spans{%(selector)s}[1m])
          ) by (namespace)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Exporter Queue Capacity',
        query=|||
          otelcol_exporter_queue_capacity{%(selector)s}
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Exporter Queue Size',
        query=|||
          otelcol_exporter_queue_size{%(selector)s}
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
      panel.timeSeries(
        title='Exporter Enqueue Failed Spans',
        query=|||
          sum (
            rate(otelcol_exporter_enqueue_failed_spans{%(selector)s}[1m])
          ) by (namespace)
        ||| % { selector: collectorSelectorSerialized },
        legendFormat='{{ namespace }}',
      ),
    ],
    cols=4,
    rowHeight=8,
    startRow=401,
  )
)
.addPanel(
  row.new(title='Trace Query API'),
  gridPos={ x: 0, y: 500, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Request rate',
        query=|||
          sum(
            rate(http_requests_total{%(selector)s}[1m])
          ) by (path, code)
        ||| % { selector: queryAPISelectorSerialized },
        legendFormat='{{ container }}',
      ),
      panel.timeSeries(
        title='95th percentile Request Latency',
        query=|||
          histogram_quantile(
            0.95,
            sum(
              rate(http_requests_duration_seconds_bucket{%(selector)s}[1m])
            ) by (le)
          )
        ||| % { selector: queryAPISelectorSerialized },
        legendFormat='{{ container }}',
      ),
      panel.timeSeries(
        title='95th percentile Response Size',
        query=|||
          histogram_quantile(
            0.95,
            sum(
              rate(http_response_size_bucket{%(selector)s}[1m])
            ) by (le)
          )
        ||| % { selector: queryAPISelectorSerialized },
        legendFormat='{{ container }}',
      ),
    ],
    cols=3,
    rowHeight=8,
    startRow=501,
  )
)
