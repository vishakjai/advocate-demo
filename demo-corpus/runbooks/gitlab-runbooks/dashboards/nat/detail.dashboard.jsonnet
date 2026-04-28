local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local gatewayNameTemplate = grafana.template.new(
  'gateway',
  '$PROMETHEUS_DS',
  'label_values(stackdriver_nat_gateway_logging_googleapis_com_user_nat_translations{environment="$environment"}, gateway_name)',
  current='gitlab-gke',
  refresh='load',
  sort=1,
);

local errorsPanel =
  panel.basic('Cloud NAT errors')
  .addTarget(
    target.prometheus(
      |||
        stackdriver_nat_gateway_logging_googleapis_com_user_nat_errors{environment="$environment"}
      |||,
      legendFormat='errors'
    ),
  )
  .addTarget(
    target.prometheus(
      |||
        stackdriver_nat_gateway_logging_googleapis_com_user_nat_translations{environment="$environment"}
      |||,
      legendFormat='translations'
    ),
  );

local errorsPerHostPanel =
  panel.basic('Cloud NAT errors per host')
  .addTarget(
    target.prometheus(
      |||
        stackdriver_nat_gateway_logging_googleapis_com_user_nat_errors_by_vm{environment="$environment"}
      |||,
      legendFormat='errors'
    ),
  );

basic.dashboard(
  'Cloud NAT Detail',
  tags=['general'],
)
.addTemplate(gatewayNameTemplate)
.addPanels(layout.grid([
  errorsPanel,
  errorsPerHostPanel,
], cols=1, rowHeight=10))
