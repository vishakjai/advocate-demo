local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local services = (import 'gitlab-metrics-config.libsonnet').monitoredServices;
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local keyMetrics = import 'gitlab-dashboards/key_metrics.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local text = grafana.text;

local selector = {};

local tierOrder = [
  'sv',
  'stor',
  'inf',
  'db',
];

local servicesOrdered = std.sort(
  services,
  function(s)
    local indexes = std.find(s.tier, tierOrder);
    local tierIndex = if std.length(indexes) == 0 then
      error 'Unable to find tier %s in tierOrder' % s.tier
    else
      indexes[0];

    '%d-%s' % [tierIndex, s.type]
);

// Generate a row for each service
local serviceRows = std.foldl(
  function(memo, service)
    local startRow = 1100 + (std.length(memo) * 100);
    local formatConfig = {
      serviceType: service.type,
    };

    local hasApdex = service.hasApdex();
    local hasErrorRate = service.hasErrorRate();
    local hasRequestRate = service.hasRequestRate();

    memo + keyMetrics.headlineMetricsRow(
      service.type,
      startRow=startRow,
      rowTitle='%(serviceType)s Service' % formatConfig,
      selectorHash=selector,
      stableIdPrefix=service.type,
      showApdex=hasApdex,
      showErrorRatio=hasErrorRate,
      showOpsRate=hasRequestRate,
      showDashboardListPanel=true
    ),
  servicesOrdered,
  []
);

// TODO: generate this dashboard directly from the service-catalog
basic.dashboard(
  'Triage',
  tags=['general']
)
.addPanel(
  row.new(title='SERVICES'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(serviceRows)
.trailer()
{
  uid: 'triage',
}
