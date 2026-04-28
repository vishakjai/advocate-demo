local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local selector = { env: '$environment', stage: '$stage', type: 'kas' };
local selectorString = selectors.serializeHash(selector);

basic.dashboard(
  'CI tunnel',
  tags=[
    'kas',
  ],
)
.addTemplate(templates.stage)
.addPanels(
  layout.grid(
    [
      basic.heatmap(
        title='Routing latency (success)',
        description='Time it takes kas to find a suitable reverse tunnel from an agent',
        query='sum by (le) (rate(tunnel_routing_duration_seconds_bucket{%s, status="success"}[$__rate_interval]))' % selectorString,
        dataFormat='tsbuckets',
        color_cardColor='#00ff00',
        color_colorScheme='Spectral',
        color_mode='spectrum',
        legendFormat='__auto',
      ),
      basic.heatmap(
        title='Routing latency (request aborted)',
        description='Time it takes kas to find a suitable reverse tunnel from an agent',
        query='sum by (le) (rate(tunnel_routing_duration_seconds_bucket{%s, status="aborted"}[$__rate_interval]))' % selectorString,
        dataFormat='tsbuckets',
        color_cardColor='#0000ff',
        color_colorScheme='Spectral',
        color_mode='spectrum',
        legendFormat='__auto',
      ),
      panel.timeSeries(
        title='Routing request timed out for recently connected agents',
        description='CI tunnel request routing took longer than 20s for agents that have recently connected (within the last 15 minutes)',
        query=|||
          sum (increase(tunnel_routing_timeout_connected_recently_total{%s}[$__rate_interval]))
        ||| % selectorString,
        yAxisLabel='requests',
        legend_show=false,
      ),
      panel.timeSeries(
        title='Routing request timed out for disconnected agents',
        description='CI tunnel request routing took longer than 20s for agents that are disconnected',
        query=|||
          sum (increase(tunnel_routing_timeout_not_connected_recently_total{%s}[$__rate_interval]))
        ||| % selectorString,
        yAxisLabel='requests',
        legend_show=false,
      ),
      panel.timeSeries(
        title='OK gRPC calls/second',
        description='OK gRPC calls related to CI tunnel',
        query=|||
          sum by (grpc_service, grpc_method) (
            rate(grpc_server_handled_total{%s, grpc_code="OK",
              grpc_service=~"gitlab.agent.reverse_tunnel.rpc.ReverseTunnel|gitlab.agent.kubernetes_api.rpc.KubernetesApi"
            }[$__rate_interval])
          )
        ||| % selectorString,
        legendFormat='{{grpc_service}}/{{grpc_method}}',
        yAxisLabel='rps',
        linewidth=1,
      ),
      panel.timeSeries(
        title='Not OK gRPC calls/second',
        description='Not OK gRPC calls related to CI tunnel',
        query=|||
          sum by (grpc_service, grpc_method, grpc_code) (
            rate(grpc_server_handled_total{%s, grpc_code!="OK",
              grpc_service=~"gitlab.agent.reverse_tunnel.rpc.ReverseTunnel|gitlab.agent.kubernetes_api.rpc.KubernetesApi"
            }[$__rate_interval])
          )
        ||| % selectorString,
        legendFormat='{{grpc_service}}/{{grpc_method}} {{grpc_code}}',
        yAxisLabel='rps',
        linewidth=1,
      ),
      basic.heatmap(
        title='I/O task submission latency',
        description='The time it takes to submit a tunnel tracking task',
        query='sum by (le) (rate(registry_async_submission_duration_seconds_bucket{%s}[$__rate_interval]))' % selectorString,
        dataFormat='tsbuckets',
        color_cardColor='#0000ff',
        color_colorScheme='Spectral',
        color_mode='spectrum',
        legendFormat='__auto',
      ),
      panel.timeSeries(
        title='Number of I/O tasks submitted',
        description='',
        query=|||
          sum by (pod) (increase(registry_async_submission_total{%s}[$__rate_interval]))
        ||| % selectorString,
        legendFormat='__auto',
        linewidth=1,
      ),
      basic.heatmap(
        title='Size of the Redis I/O batch',
        query='sum by (le) (rate(registry_async_submission_batch_size_bucket{%s}[$__rate_interval]))' % selectorString,
        dataFormat='tsbuckets',
        yAxis_format='',
        color_cardColor='#0000ff',
        color_colorScheme='Spectral',
        color_mode='spectrum',
        legendFormat='__auto',
      ),
    ],
    cols=3,
    rowHeight=10,
  )
)
