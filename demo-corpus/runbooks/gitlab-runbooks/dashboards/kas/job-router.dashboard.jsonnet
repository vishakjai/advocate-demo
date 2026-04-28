local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local selector = { env: '$environment', stage: '$stage', type: 'kas' };
local selectorString = selectors.serializeHash(selector);

local grpcSelector = selector { grpc_service: 'gitlab.agent.job_router.rpc.JobRouter', grpc_method: 'GetJob' };
local grpcSelectorString = selectors.serializeHash(grpcSelector);

basic.dashboard(
  'Job Router',
  tags=[
    'kas',
    'job-router',
  ],
)
.addTemplate(templates.stage)
.addPanels(
  layout.titleRowWithPanels(
    'GetJob RPC',
    layout.grid(
      [
        panel.timeSeries(
          title='GetJob Requests/sec',
          description='Rate of GetJob gRPC calls to the Job Router',
          query=|||
            sum(rate(grpc_server_handled_total{%s}[$__rate_interval]))
          ||| % grpcSelectorString,
          yAxisLabel='rps',
          legend_show=false,
        ),
        basic.gaugePanel(
          'GetJob Success Rate',
          query=|||
            sum(rate(grpc_server_handled_total{%(selector)s, grpc_code="OK"}[$__rate_interval])) /
            sum(rate(grpc_server_handled_total{%(selector)s}[$__rate_interval])) * 100
          ||| % { selector: grpcSelectorString },
          instant=false,
          unit='percent',
        ),
        panel.timeSeries(
          title='GetJob by Response Code',
          description='Breakdown of GetJob calls by gRPC response code',
          query=|||
            sum by (grpc_code) (rate(grpc_server_handled_total{%s}[$__rate_interval]))
          ||| % grpcSelectorString,
          legendFormat='{{grpc_code}}',
          yAxisLabel='rps',
          linewidth=1,
        ),
        basic.heatmap(
          title='GetJob Latency',
          description='Latency distribution for GetJob gRPC calls',
          query='sum by (le) (rate(grpc_server_handling_seconds_bucket{%s}[$__rate_interval]))' % grpcSelectorString,
          dataFormat='tsbuckets',
          color_cardColor='#00ff00',
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
    'Admission Control',
    layout.grid(
      [
        // Per-Job Admission Control metrics
        panel.timeSeries(
          title='Admission Decisions/sec',
          description='Rate of per-job admission control decisions',
          query=|||
            sum(rate(job_router_admission_control_total{%s}[$__rate_interval]))
          ||| % selectorString,
          yAxisLabel='decisions/s',
          legend_show=false,
        ),
        panel.timeSeries(
          title='Admission Decisions by Result',
          description='Breakdown of admission control decisions: admitted (job allowed), rejected (job rejected), disabled (feature disabled), failed (error occurred)',
          query=|||
            sum by (result) (rate(job_router_admission_control_total{%s}[$__rate_interval]))
          ||| % selectorString,
          legendFormat='{{result}}',
          yAxisLabel='decisions/s',
          linewidth=1,
        ),
        basic.gaugePanel(
          'Job Admitted Rate',
          query=|||
            sum(rate(job_router_admission_control_total{%(selector)s, result="admitted"}[$__rate_interval])) /
            sum(rate(job_router_admission_control_total{%(selector)s}[$__rate_interval])) * 100
          ||| % { selector: selectorString },
          instant=false,
          unit='percent',
        ),
        // Per-Controller Request metrics
        panel.timeSeries(
          title='Admission Controller Requests/sec',
          description='Rate of admission control requests to individual runner controllers (0 or more per job)',
          query=|||
            sum by (dry_run) (rate(job_router_admission_control_requests_total{%s}[$__rate_interval]))
          ||| % selectorString,
          legendFormat='dry_run={{dry_run}}',
          yAxisLabel='requests/s',
        ),
        panel.timeSeries(
          title='Admission Controller Requests by Result',
          description='Breakdown of requests to runner controllers: admitted (job allowed), rejected (job rejected), or failed (error occurred)',
          query=|||
            sum by (result, dry_run) (rate(job_router_admission_control_requests_total{%s}[$__rate_interval]))
          ||| % selectorString,
          legendFormat='{{result}} (dry_run={{dry_run}})',
          yAxisLabel='requests/s',
          linewidth=1,
        ),
      ],
      startRow=2000,
    ),
    collapse=false,
    startRow=1000
  )
)
