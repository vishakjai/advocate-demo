local panels = import 'gitlab-dashboards/pgbouncer-panels.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

panels.pgbouncer()
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Sync Pool',
        description='Total sync (web/api/git) pool utilisation by job.',
        query=
        |||
          sum by (controller, stage) (
            rate(gitlab_transaction_duration_seconds_sum{environment="$environment", env="$environment", monitor="app", type!="sidekiq", controller!="Grape"}[$__interval])
          )
          or
          label_replace(
            sum by (action, stage) (
              rate(gitlab_transaction_duration_seconds_sum{environment="$environment", env="$environment", monitor="app", type!="sidekiq", controller="Grape"}[$__interval])
            ),
            "controller", "$1", "action", "(.*)"
          )
        |||,
        legendFormat='{{ controller }} - {{ stage }} stage',
        format='s',
        yAxisLabel='"Usage client transaction time/sec',
        interval='1m',
        intervalFactor=1,
        legend_show=false,
        linewidth=1
      ),
    ],
    cols=2,
    startRow=5001,
  )
)
.overviewTrailer()
