local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

serviceDashboard.overview('frontend')
.addPanel(
  grafana.row.new(title='HAProxy Process'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  processExporter.namedGroup(
    'haproxy',
    {
      environment: '$environment',
      groupname: 'haproxy',
      type: 'frontend',
      stage: '$stage',
    },
    startRow=1001,
  )
)
.overviewTrailer()
