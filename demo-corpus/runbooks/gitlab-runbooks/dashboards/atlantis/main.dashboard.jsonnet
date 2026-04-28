local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;

local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

serviceDashboard.overview('atlantis', startRow=1, omitEnvironmentDropdown=true)
.addTemplate(
  template.custom(
    'environment',
    'ops,',
    'ops',
  ),
)
.overviewTrailer()
