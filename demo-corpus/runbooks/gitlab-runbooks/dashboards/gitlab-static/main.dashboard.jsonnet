local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

local environmentSelector = { env: 'ops', environment: 'ops' };

serviceDashboard.overview(
  'gitlab-static',
  environmentSelectorHash=environmentSelector,
  saturationEnvironmentSelectorHash=environmentSelector,
)
.overviewTrailer()
