local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local row = grafana.row;

local trafficPanel() =
  panel.timeSeries(
    'Traffic',
    description='Traffic, in bytes per second',
    query='sum(rate(camo_response_size_bytes_sum{environment="$environment"}[$__interval]))',
    format='B'
  );

local eventPanel() =
  panel.timeSeries(
    'Request Failures',
    description='Failed requests',
    query='sum(rate(camo_proxy_reponses_failed_total{environment="$environment"}[$__interval]))',
    legendFormat='Failed Requests',
  )
  .addTarget(
    target.prometheus(
      'sum(rate(camo_proxy_content_length_exceeded_total{environment="$environment"}[$__interval]))',
      legendFormat='Content Length Exceeded - --max-size exceeded',
    )
  )
  .addTarget(
    target.prometheus(
      'sum(rate(camo_proxy_reponses_truncated_total{environment="$environment"}[$__interval]))',
      legendFormat='Response Truncated - --max-size exceeded',
    )
  )
  .addTarget(
    target.prometheus(
      'sum(rate(camo_responses_total{environment="$environment",code="504"}[$__interval]))',
      legendFormat='504 - Gateway Timeout - maybe --timeout exceeded',
    )
  );

serviceDashboard.overview('camoproxy')
.addPanel(row.new(title='Proxy'), gridPos={ x: 0, y: 1000, w: 24, h: 1 })
.addPanels(layout.grid([
  trafficPanel(),
  eventPanel(),
], cols=2, rowHeight=10, startRow=1000))
.overviewTrailer()
