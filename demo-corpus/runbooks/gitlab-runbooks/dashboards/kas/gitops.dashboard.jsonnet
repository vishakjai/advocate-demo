local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local selector = { env: '$environment', stage: '$stage', type: 'kas' };
local selectorString = selectors.serializeHash(selector);

basic.dashboard(
  'GitOps metrics',
  tags=[
    'kas',
  ],
)
.addTemplate(templates.stage)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Flux: Git push notifications sent',
        description='The total number of sent Git Push notifications to agentks in Flux module',
        query=|||
          sum (increase(flux_git_push_notifications_total{%s}[$__rate_interval]))
        ||| % selectorString,
        yAxisLabel='count',
        legend_show=false,
        linewidth=1,
      ),
      panel.timeSeries(
        title='Flux: Git push notifications dropped',
        description='The total number of dropped Git push notifications in Flux module',
        query=|||
          sum (increase(flux_dropped_git_push_notifications_total{%s}[$__rate_interval]))
        ||| % selectorString,
        yAxisLabel='count',
        legend_show=false,
        linewidth=1,
      ),
      panel.timeSeries(
        title='Git push notifications RPCs',
        description='Git push gRPC notifications',
        query=|||
          sum by (grpc_code) (
            rate(grpc_server_handled_total{%s,
              grpc_service="gitlab.agent.notifications.rpc.Notifications",
              grpc_method="GitPushEvent"
            }[$__rate_interval])
          )
        ||| % selectorString,
        legendFormat='gitlab.agent.notifications.rpc.Notifications/GitPushEvent {{grpc_code}}',
        yAxisLabel='rps',
        linewidth=1,
      ),
      panel.timeSeries(
        title='OK gRPC calls/second',
        description='OK gRPC calls related to GitOps',
        query=|||
          sum by (grpc_service, grpc_method) (
            rate(grpc_server_handled_total{%s, grpc_code="OK",
              grpc_service=~"gitlab.agent.gitops.rpc.Gitops|gitlab.agent.flux.rpc.GitLabFlux"
            }[$__rate_interval])
          )
        ||| % selectorString,
        legendFormat='{{grpc_service}}/{{grpc_method}}',
        yAxisLabel='rps',
        linewidth=1,
      ),
      panel.timeSeries(
        title='Not OK gRPC calls/second',
        description='Not OK gRPC calls related to GitOps',
        query=|||
          sum by (grpc_service, grpc_method, grpc_code) (
            rate(grpc_server_handled_total{%s, grpc_code!="OK",
              grpc_service=~"gitlab.agent.gitops.rpc.Gitops|gitlab.agent.flux.rpc.GitLabFlux"
            }[$__rate_interval])
          )
        ||| % selectorString,
        legendFormat='{{grpc_service}}/{{grpc_method}} {{grpc_code}}',
        yAxisLabel='rps',
        linewidth=1,
      ),
    ],
    cols=3,
    rowHeight=10,
  )
)
