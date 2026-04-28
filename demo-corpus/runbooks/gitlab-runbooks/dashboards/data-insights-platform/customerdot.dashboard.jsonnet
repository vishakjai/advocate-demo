local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local k8sPodsCommon = import 'gitlab-dashboards/kubernetes_pods_common.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local platformSelector = {
  env: '$environment',
  cluster: '$cluster',
  namespace: '$namespace',
};
local platformSelectorSerialized = selectors.serializeHash(platformSelector);

basic.dashboard(
  'Usage Billing',
  tags=[
    'k8s',
    'customerdot',
    'data-insights-platform',
    'analytics-section',
    'platform-insights',
  ],
  defaultDatasource=mimirHelper.mimirDatasource('fulfillment-platform')
)
.addTemplate(
  template.custom(
    name='environment',
    label='Environment',
    query='gstg,gprd',
    current='gstg',
  )
)
.addTemplate(template.new(
  'cluster',
  '$PROMETHEUS_DS',
  'label_values(kube_pod_container_info{env="$environment", cluster=~".*-customers-gke"}, cluster)',
  label='Cluster',
  refresh='load',
  sort=1,
))
.addTemplate(
  template.custom(
    name='namespace',
    query='data-insights-platform',
    current='data-insights-platform',
    hide='variable',
  )
)
.addTemplate(
  template.custom(
    name='Deployment',
    query='data-insights-platform-single',
    current='data-insights-platform-single',
    hide='variable',
  )
)
.addPanel(
  row.new(title='Description'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      basic.text(
        content=|||
          # Data Insights Platform - Usage Billing

          This dashboard helps monitor `customerdot` instances of Data Insights Platform - used to service Usage Billing.
          For more information, please see:

          - [Productionizing Data Insights Platform for Usage Billing](https://gitlab.com/groups/gitlab-org/analytics-section/-/epics/14)
          - [Readiness Review: Data Insights Platform](https://gitlab.com/gitlab-com/gl-infra/readiness/-/issues/131)
          - [Runbooks](https://gitlab.com/gitlab-com/runbooks/-/tree/master/docs/data-insights-platform?ref_type=heads)
        |||,
      ),
    ],
    cols=1,
    rowHeight=5,
    startRow=1,
  )
)
.addPanel(
  row.new(title='Throughput'),
  gridPos={ x: 0, y: 100, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Requests',
        query=|||
          sum (
            rate(raw_ingestion_http_requests_total{%(selector)s, code="200"}[$__interval])
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='requests',
        legendFormat='requests',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Errors',
        query=|||
          sum (
            rate(raw_ingestion_http_requests_total{%(selector)s, code!="200"}[$__interval]) or vector(0)
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='errors',
        legendFormat='errors',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Ingestion latency - p99',
        query=|||
          1000 * histogram_quantile(
            0.99,
            sum(
              rate(raw_ingestion_latency_seconds_bucket{%(selector)s}[$__interval])
            ) by (le)
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='milliseconds',
        format='ms',
        legendFormat='latency',
        fill=50,
        stack=true,
      ),
    ],
    cols=3,
    rowHeight=10,
    startRow=101,
  )
)
.addPanel(
  row.new(title='Resources'),
  gridPos={ x: 0, y: 200, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Active version',
        query=|||
          count(kube_pod_container_info{%(selector)s, pod=~"^data-insights-platform-single.*$"}) by (image)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='{{ image }}',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Statefulset replica count',
        query=|||
          kube_statefulset_replicas{%(selector)s}
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='replicas',
        fill=50,
        stack=true,
      ),
    ],
    cols=2,
    rowHeight=6,
    startRow=201,
  )
)
.addPanel(
  row.new(title='Consumption'),
  gridPos={ x: 0, y: 300, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Total CPU usage',
        query=|||
          sum(
            rate(container_cpu_usage_seconds_total{%(selector)s, container="data-insights-platform-single"}[$__rate_interval])
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='cores',
        legendFormat='cpu',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Total memory usage',
        query=|||
          sum(
            container_memory_working_set_bytes{%(selector)s, container="data-insights-platform-single"}
          ) / (1024*1024)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='MB',
        legendFormat='memory',
        fill=50,
        stack=true,
      ),
    ],
    cols=2,
    rowHeight=6,
    startRow=301,
  )
)
.addPanel(
  row.new(title='Enrichment'),
  gridPos={ x: 0, y: 400, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Enrichment Latency - p99',
        query=|||
          1000 * histogram_quantile(
            0.99,
            sum(
              rate(messages_enrichment_latency_seconds_bucket{%(selector)s}[$__interval])
            ) by (le)
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='milliseconds',
        format='ms',
        legendFormat='latency',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Payloads to process/enrich',
        query=|||
          sum (
            rate(messages_sent_to_enrichment_count{%(selector)s}[$__interval])
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='messages',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Individual events generated',
        query=|||
          sum (
            rate(events_post_enrichment_count{%(selector)s}[$__interval])
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='events',
        fill=50,
        stack=true,
      ),
    ],
    cols=3,
    rowHeight=6,
    startRow=401,
  )
)
.addPanel(
  row.new(title='Data Export'),
  gridPos={ x: 0, y: 500, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Individual good events ready to export',
        query=|||
          sum (
            rate(events_published_count{%(selector)s}[$__interval])
          ) by (exported_type)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='{{ exported_type }}',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Successful exports to ClickHouse',
        query=|||
          sum (
            rate(events_sent_to_exporter_count{%(selector)s, exporter="billingexporter", success="1"}[$__interval])
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='events',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Failed exports to ClickHouse',
        query=|||
          sum (
            rate(events_sent_to_exporter_count{%(selector)s, exporter="billingexporter", success="0"}[$__interval])
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='events',
        fill=50,
        stack=true,
      ),
    ],
    cols=3,
    rowHeight=6,
    startRow=501,
  )
)
.addPanel(
  row.new(title='Iglu resources'),
  gridPos={ x: 0, y: 600, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Schema lookups',
        query=|||
          sum(
            rate(schema_lookup_count{%(selector)s, container="data-insights-platform-single"}[$__rate_interval])
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='lookups',
        fill=50,
        stack=true,
      ),
      panel.timeSeries(
        title='Schemas served from cache',
        query=|||
          sum(
            rate(schema_served_from_cache_count{%(selector)s, container="data-insights-platform-single"}[$__rate_interval])
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        legendFormat='cached lookups',
        fill=50,
        stack=true,
      ),
    ],
    cols=2,
    rowHeight=6,
    startRow=601,
  )
)
.trailer()
+ {
  links+: platformLinks.triage +
          platformLinks.services,
}
