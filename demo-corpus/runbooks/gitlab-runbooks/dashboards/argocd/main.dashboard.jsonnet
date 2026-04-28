local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

serviceDashboard.overview(
  'argocd',
  omitEnvironmentDropdown=true,
  environmentSelectorHash={ env: 'ops' },
)
.overviewTrailer()
