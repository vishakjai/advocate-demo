local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local selector = { env: '$environment', stage: '$stage', type: 'kas' };
local selectorString = selectors.serializeHash(selector);

local envSelector = { env: '$environment', type: 'kas' };
local envSelectorString = selectors.serializeHash(envSelector);

basic.dashboard(
  'Miscellaneous metrics',
  tags=[
    'kas',
  ],
)
.addTemplate(templates.stage)
.addPanels(
  layout.titleRowWithPanels(
    'Rate limiter metrics',
    layout.grid(
      [
        basic.heatmap(
          title='Rate limiter delay (allowed, agent_connection)',
          description='Rate limiter delay for an allowed request',
          query='sum by (le) (\n            rate(limiter_block_duration_seconds_bucket{%s, allowed="true", limiter_name="agent_connection"}[$__rate_interval])\n          )' % selectorString,
          dataFormat='tsbuckets',
          color_cardColor='#00ff00',
          color_colorScheme='Spectral',
          color_mode='spectrum',
          legendFormat='__auto',
        ),
        basic.heatmap(
          title='Rate limiter delay (denied, agent_connection)',
          description='Rate limiter delay for a denied request',
          query='sum by (le) (\n            rate(limiter_block_duration_seconds_bucket{%s, allowed="false", limiter_name="agent_connection"}[$__rate_interval])\n          )' % selectorString,
          dataFormat='tsbuckets',
          color_cardColor='#ff0000',
          color_colorScheme='Spectral',
          color_mode='spectrum',
          legendFormat='__auto',
        ),

        basic.heatmap(
          title='Rate limiter delay (allowed, gitaly_client_global)',
          description='Rate limiter delay for an allowed request',
          query='sum by (le) (\n            rate(limiter_block_duration_seconds_bucket{%s, allowed="true", limiter_name="gitaly_client_global"}[$__rate_interval])\n          )' % selectorString,
          dataFormat='tsbuckets',
          color_cardColor='#00ff00',
          color_colorScheme='Spectral',
          color_mode='spectrum',
          legendFormat='__auto',
        ),
        basic.heatmap(
          title='Rate limiter delay (denied, gitaly_client_global)',
          description='Rate limiter delay for a denied request',
          query='sum by (le) (\n            rate(limiter_block_duration_seconds_bucket{%s, allowed="false", limiter_name="gitaly_client_global"}[$__rate_interval])\n          )' % selectorString,
          dataFormat='tsbuckets',
          color_cardColor='#ff0000',
          color_colorScheme='Spectral',
          color_mode='spectrum',
          legendFormat='__auto',
        ),

        basic.heatmap(
          title='Rate limiter delay (allowed, gitlab_client)',
          description='Rate limiter delay for an allowed request',
          query='sum by (le) (\n            rate(limiter_block_duration_seconds_bucket{%s, allowed="true", limiter_name="gitlab_client"}[$__rate_interval])\n          )' % selectorString,
          dataFormat='tsbuckets',
          color_cardColor='#00ff00',
          color_colorScheme='Spectral',
          color_mode='spectrum',
          legendFormat='__auto',
        ),
        basic.heatmap(
          title='Rate limiter delay (denied, gitlab_client)',
          description='Rate limiter delay for a denied request',
          query='sum by (le) (\n            rate(limiter_block_duration_seconds_bucket{%s, allowed="false", limiter_name="gitlab_client"}[$__rate_interval])\n          )' % selectorString,
          dataFormat='tsbuckets',
          color_cardColor='#ff0000',
          color_colorScheme='Spectral',
          color_mode='spectrum',
          legendFormat='__auto',
        ),
      ],
      startRow=1000,
    ),
    collapse=false,
    startRow=0
  )
)
.addPanels(
  layout.titleRowWithPanels(
    'gRPC metrics',
    layout.grid(
      [
        panel.timeSeries(
          title='OK gRPC calls/second',
          description='OK gRPC calls',
          query=|||
            sum by (grpc_service, grpc_method) (
              rate(grpc_server_handled_total{%s, grpc_code="OK"}[$__rate_interval])
            )
          ||| % selectorString,
          legendFormat='{{grpc_service}}/{{grpc_method}}',
          yAxisLabel='rps',
          linewidth=1,
        ),
        panel.timeSeries(
          title='Not OK gRPC calls/second',
          description='Not OK gRPC calls',
          query=|||
            sum by (grpc_service, grpc_method, grpc_code) (
              rate(grpc_server_handled_total{%s, grpc_code!="OK"}[$__rate_interval])
            )
          ||| % selectorString,
          legendFormat='{{grpc_service}}/{{grpc_method}} {{grpc_code}}',
          yAxisLabel='rps',
          linewidth=1,
        ),
      ],
      startRow=3000,
    ),
    collapse=false,
    startRow=2000
  )
)
.addPanels(
  layout.titleRowWithPanels(
    'Performance',
    layout.grid(
      [
        panel.timeSeries(
          title='CPU throttling',
          description='CPU throttling of kas',
          query=|||
            sum (rate(container_cpu_cfs_throttled_seconds_total{%s}[$__rate_interval]))
          ||| % selectorString,
          yAxisLabel='time',
          legend_show=false,
          linewidth=1,
        ),
        panel.timeSeries(
          title='Go GC',
          description='',
          query=|||
            1000*go_gc_duration_seconds{%s,quantile="1"}
          ||| % selectorString,
          yAxisLabel='milliseconds',
          legend_show=false,
          linewidth=1,
        ),
        panel.timeSeries(
          title='Go goroutines',
          description='',
          query=|||
            go_goroutines{%s}
          ||| % selectorString,
          yAxisLabel='',
          legend_show=false,
          linewidth=1,
        ),
      ],
      startRow=5000,
    ),
    collapse=false,
    startRow=4000
  )
)
.addPanels(
  layout.titleRowWithPanels(
    'Misc',
    layout.grid(
      [
        panel.timeSeries(
          title='Running version',
          description='Running version of kas',
          query=|||
            count by (git_ref, stage) (gitlab_build_info{%s})
          ||| % envSelectorString,
          yAxisLabel='pods',
          legend_show=false,
          linewidth=1,
          stack=true,
          fill=30,
        ),
      ],
      startRow=7000,
    ),
    collapse=false,
    startRow=6000
  )
)
