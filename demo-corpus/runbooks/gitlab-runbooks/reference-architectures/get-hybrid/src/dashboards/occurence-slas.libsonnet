local occurenceSLADashboard = import 'gitlab-dashboards/occurrence-sla-dashboard.libsonnet';
local metricsConfig = import 'gitlab-metrics-config.libsonnet';

local serviceWeights = {
  [service]: 1
  for service in metricsConfig.keyServices
};
occurenceSLADashboard.dashboard(
  serviceWeights,
  metricsConfig.aggregationSets.serviceSLIs,
  metricsConfig.slaTarget,
  sortedServices=metricsConfig.keyServices
)
