local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

serviceDashboard.overview('wiz-runtime-sensor')
.addPanel(
  grafana.row.new(title='Wiz Process'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  processExporter.namedGroup(
    'wiz-sensor',
    {
      environment: '$environment',
      groupname: 'wiz-sensor',
    },
    startRow=1001,
  ),
)
.overviewTrailer()
