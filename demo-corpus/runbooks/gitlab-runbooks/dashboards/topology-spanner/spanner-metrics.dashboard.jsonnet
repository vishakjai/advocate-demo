local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local instanceIdTemplate = grafana.template.new(
  'instance_id',
  '$PROMETHEUS_DS',
  'label_values(stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{job="runway-exporter", project_id="gitlab-runway-topo-svc-prod"}, instance_id)',
  current='all',
  refresh='load',
  includeAll=true,
  multi=true,
  sort=1,
);

local methodTemplate = grafana.template.new(
  'method',
  '$PROMETHEUS_DS',
  'label_values(stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{job="runway-exporter", project_id="gitlab-runway-topo-svc-prod", instance_id=~"$instance_id"}, method)',
  current='all',
  refresh='load',
  includeAll=true,
  multi=true,
  sort=1,
);

local apiLatencyPanel =
  panel.basic('API Request Latency by Method')
  .addTarget(
    target.prometheus(
      |||
        sum(rate(stackdriver_spanner_instance_spanner_googleapis_com_api_request_latencies_per_transaction_options_sum{
          job="runway-exporter",
          project_id="gitlab-runway-topo-svc-prod",
          instance_id=~"$instance_id",
          method=~"$method"
        }[5m])) by (method, instance_id)
        /
        sum(rate(stackdriver_spanner_instance_spanner_googleapis_com_api_request_latencies_per_transaction_options_count{
          job="runway-exporter",
          project_id="gitlab-runway-topo-svc-prod",
          instance_id=~"$instance_id",
          method=~"$method"
        }[5m])) by (method, instance_id)
      |||,
      legendFormat='{{instance_id}} - {{method}}'
    ),
  );

local apiErrorRatePanel =
  panel.basic('API Error Rate (non-OK status)')
  .addTarget(
    target.prometheus(
      |||
        sum(rate(stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{
          job="runway-exporter",
          project_id="gitlab-runway-topo-svc-prod",
          instance_id=~"$instance_id",
          method=~"$method",
          status!="OK"
        }[5m])) by (method, status, instance_id)
      |||,
      legendFormat='{{instance_id}} - {{method}} - {{status}}'
    ),
  );

local apiRequestRatePanel =
  panel.basic('API Request Rate')
  .addTarget(
    target.prometheus(
      |||
        sum(rate(stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{
          job="runway-exporter",
          project_id="gitlab-runway-topo-svc-prod",
          instance_id=~"$instance_id",
          method=~"$method"
        }[5m])) by (method, instance_id)
      |||,
      legendFormat='{{instance_id}} - {{method}}'
    ),
  );

local apiErrorPercentagePanel =
  panel.basic('API Error Percentage')
  .addTarget(
    target.prometheus(
      |||
        sum(rate(stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{
          job="runway-exporter",
          project_id="gitlab-runway-topo-svc-prod",
          instance_id=~"$instance_id",
          method=~"$method",
          status!="OK"
        }[5m])) by (method, instance_id)
        /
        sum(rate(stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{
          job="runway-exporter",
          project_id="gitlab-runway-topo-svc-prod",
          instance_id=~"$instance_id",
          method=~"$method"
        }[5m])) by (method, instance_id)
        * 100
      |||,
      legendFormat='{{instance_id}} - {{method}}'
    ),
  );

basic.dashboard(
  'Topology Spanner Metrics',
  tags=['type:topology-spanner', 'detail', 'spanner', 'topology', 'cells'],
)
.addTemplate(instanceIdTemplate)
.addTemplate(methodTemplate)
.addPanels(layout.grid([
  apiLatencyPanel,
  apiRequestRatePanel,
  apiErrorRatePanel,
  apiErrorPercentagePanel,
], cols=2, rowHeight=10))
