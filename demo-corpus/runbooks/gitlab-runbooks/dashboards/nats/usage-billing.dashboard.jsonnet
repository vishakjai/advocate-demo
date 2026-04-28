local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local templates = import 'grafana/templates.libsonnet';
local template = grafana.template;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local environmentSelector = {
  env: '$environment',
};
local environmentSelectorSerialized = selectors.serializeHash(environmentSelector);

local platformSelector = {
  env: '$environment',
  cluster: '$cluster',
  namespace: '$namespace',
};
local platformSelectorSerialized = selectors.serializeHash(platformSelector);

basic.dashboard(
  'NATS - Usage Billing',
  tags=[
    'k8s',
    'data-insights-platform',
    'analytics-section',
    'platform-insights',
    'customerdot',
    'usage-billing',
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
.addTemplate(
  template.new(
    'cluster',
    '$PROMETHEUS_DS',
    'label_values(kube_pod_container_info{env="$environment", cluster=~".*-customers-gke"}, cluster)',
    label='Cluster',
    refresh='load',
    sort=1,
  )
)
.addTemplate(
  template.custom(
    name='namespace',
    query='nats',
    current='nats',
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
          # NATS - Usage Billing

          This dashboard helps monitor `customerdot` instances of NATS - used to service Usage Billing. Note, these NATS
          instances are deployed as an internal part of Data Insights Platform.

          For more information, please see:

          - [Productionizing Data Insights Platform for Usage Billing](https://gitlab.com/groups/gitlab-org/analytics-section/-/epics/14)
          - [Readiness Review: Data Insights Platform](https://gitlab.com/gitlab-com/gl-infra/readiness/-/issues/131)
          - [Runbooks](https://gitlab.com/gitlab-com/runbooks/-/tree/master/docs/data-insights-platform?ref_type=heads)
        |||,
      ),
    ],
    cols=1,
    rowHeight=6,
    startRow=1,
  )
)
.addPanel(
  row.new(title='Server Resources'),
  gridPos={ x: 0, y: 100, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='CPU',
        query=|||
          sum(
            nats_varz_cpu{%(selector)s}
          ) by (pod)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='percent',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Memory',
        query=|||
          sum(
            nats_varz_mem{%(selector)s}
          ) by (pod) / (1024*1024)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='MB',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Storage Used',
        query=|||
          100 * (
            sum(nats_varz_jetstream_stats_storage{%(selector)s}) by (pod)
            /
            sum(nats_varz_jetstream_config_max_storage{%(selector)s}) by (pod)
          )
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='percent',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
    ],
    cols=3,
    startRow=101,
  )
)
.addPanel(
  row.new(title='Throughput'),
  gridPos={ x: 0, y: 200, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Bytes In',
        query=|||
          sum(
            rate(nats_varz_in_bytes{%(selector)s}[$__rate_interval])
          ) by (pod) / (1024*1024)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='MB',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Msgs In',
        query=|||
          sum(
            rate(nats_varz_in_msgs{%(selector)s}[$__rate_interval])
          ) by (pod)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='msgs',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Bytes Out',
        query=|||
          sum(
            rate(nats_varz_out_bytes{%(selector)s}[$__rate_interval])
          ) by (pod) / (1024*1024)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='MB',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Msgs Out',
        query=|||
          sum(
            rate(nats_varz_out_msgs{%(selector)s}[$__rate_interval])
          ) by (pod)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='msgs',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
    ],
    cols=4,
    startRow=201,
  )
)
.addPanel(
  row.new(title='Client metrics'),
  gridPos={ x: 0, y: 300, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Connections',
        query=|||
          sum(
            rate(nats_varz_connections{%(selector)s}[$__rate_interval])
          ) by (pod)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Subscriptions',
        query=|||
          sum(
            rate(nats_varz_subscriptions{%(selector)s}[$__rate_interval])
          ) by (pod)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Slow consumers',
        query=|||
          sum(
            rate(nats_varz_slow_consumers{%(selector)s}[$__rate_interval])
          ) by (pod)
        ||| % { selector: platformSelectorSerialized },
        yAxisLabel='count',
        fill=50,
        legendFormat='{{pod}}',
        stack=true,
      ),
    ],
    cols=3,
    startRow=301,
  )
)
.addPanel(
  row.new(title='Per-stream stats'),
  gridPos={ x: 0, y: 400, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Total Data size',
        query=|||
          sum(
            nats_stream_total_bytes{%(selector)s}
          ) by (stream_name) / (1024*1024)
        ||| % { selector: environmentSelectorSerialized },
        yAxisLabel='MB',
        fill=50,
        legendFormat='{{stream_name}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Total Message count',
        query=|||
          sum(
            nats_stream_total_messages{%(selector)s}
          ) by (stream_name)
        ||| % { selector: environmentSelectorSerialized },
        yAxisLabel='messages',
        fill=50,
        legendFormat='{{stream_name}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Message rate per second',
        query=|||
          sum(
            rate(nats_stream_last_seq{%(selector)s}[$__rate_interval])
          ) by (stream_name)
        ||| % { selector: environmentSelectorSerialized },
        yAxisLabel='messages',
        fill=50,
        legendFormat='{{stream_name}}',
        stack=true,
      ),
    ],
    cols=3,
    startRow=401,
  )
)
.addPanel(
  row.new(title='Consumer Metrics'),
  gridPos={ x: 0, y: 500, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Messages per second',
        query=|||
          sum(
            rate(nats_consumer_num_pending{%(selector)s}[$__rate_interval])
            +
            rate(nats_consumer_delivered_consumer_seq{%(selector)s}[$__rate_interval])
          ) by (consumer_name)
        ||| % { selector: environmentSelectorSerialized },
        yAxisLabel='msgs',
        fill=50,
        legendFormat='{{consumer_name}}',
        stack=true,
      ),
    ],
    cols=1,
    startRow=501,
  ),
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Total delivered',
        query=|||
          sum(
            nats_consumer_delivered_consumer_seq{%(selector)s}
          ) by (consumer_name)
        ||| % { selector: environmentSelectorSerialized },
        yAxisLabel='msgs',
        fill=50,
        legendFormat='{{consumer_name}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Total pending',
        query=|||
          sum(
            nats_consumer_num_pending{%(selector)s}
          ) by (consumer_name)
        ||| % { selector: environmentSelectorSerialized },
        yAxisLabel='msgs',
        fill=50,
        legendFormat='{{consumer_name}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Total ACKs pending',
        query=|||
          sum(
            nats_consumer_num_ack_pending{%(selector)s}
          ) by (consumer_name)
        ||| % { selector: environmentSelectorSerialized },
        yAxisLabel='msgs',
        fill=50,
        legendFormat='{{consumer_name}}',
        stack=true,
      ),
    ],
    cols=3,
    startRow=502,
  )
)
.trailer()
