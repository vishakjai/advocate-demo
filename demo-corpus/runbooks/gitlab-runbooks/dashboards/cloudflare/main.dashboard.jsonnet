local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

local environmentSelector = { env: 'ops', environment: 'ops' };

serviceDashboard.overview(
  'cloudflare',
  environmentSelectorHash=environmentSelector,
  saturationEnvironmentSelectorHash=environmentSelector,
)
.overviewTrailer()
