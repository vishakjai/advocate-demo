local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local row = grafana.row;
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

serviceDashboard.overview('web-pages')
.addPanel(
  row.new(title='Pages Server'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.multiQuantileTimeSeries(
        title='web_pages_server Response Time',
        selector='env="$environment",stage="$stage",type="web-pages"',
        aggregators='env,environment,stage',
        bucketMetric='gitlab_pages_http_request_duration_seconds_bucket',
      ),
    ],
    startRow=1001
  )
)
.overviewTrailer()
