local generalServicesDashboard = import './general-services-dashboard.libsonnet';
local occurenceSLADashboard = import 'gitlab-dashboards/occurrence-sla-dashboard.libsonnet';
local metricsConfig = import 'gitlab-metrics-config.libsonnet';

local serviceWeights = {
  [service.name]: service.business.SLA.overall_sla_weighting
  for service in generalServicesDashboard.keyServices(includeZeroScore=true)
};
local sortedServices = std.map(function(service) service.name, generalServicesDashboard.sortedKeyServices(includeZeroScore=true));

occurenceSLADashboard.dashboard(
  serviceWeights,
  metricsConfig.aggregationSets.serviceSLIs,
  metricsConfig.slaTarget,
  { stage: 'main', environment: '$environment' },
  sortedServices=sortedServices,
)
