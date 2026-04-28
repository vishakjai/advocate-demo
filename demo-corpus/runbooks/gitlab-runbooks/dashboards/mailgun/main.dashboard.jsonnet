local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local panel = import 'grafana/time-series/panel.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

serviceDashboard.overview(
  'mailgun',
  startRow=1,
  showSystemDiagrams=false,
  showProvisioningDetails=false,
  omitEnvironmentDropdown=true,
  environmentSelectorHash={ env: 'ops' },
)
.addPanel(
  row.new(title='Mailgun Metrics'),
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
      panel.timeSeries(
        title='Mailgun Delivery Errors',
        query='sum(rate(mailgun_delivery_errors_total[$__rate_interval])) by (delivery_status_code)',
        legend_show=false,
      ),
      panel.timeSeries(
        title='Estimated p95 Delivery Time',
        query=|||
          histogram_quantile(
            0.95,
            sum by (le) (
              rate(mailgun_delivery_time_seconds_bucket[$__rate_interval])
            )
          )
        |||,
        format='s',
        legend_show=false,
      ),
      panel.timeSeries(
        title='Average deliverytime',
        query=|||
          rate(mailgun_delivery_time_seconds_sum[$__rate_interval])
          /
          rate(mailgun_delivery_time_seconds_count[$__rate_interval])
        |||,
        format='s',
        legend_show=false,
      ),
    ],
    cols=3,
    rowHeight=10,
    startRow=1001,
  )
)
.overviewTrailer()
