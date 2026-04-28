local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';

serviceDashboard.overview('external-dns')
.addPanel(
  row.new(title='ExternalDNS Sync and Reconciliation', collapse=true)
  .addPanels(
    layout.grid(
      [
        panel.timeSeries(
          title='Reconcile Lag',
          description=|||
            Time since the last reconciliation with GCP Cloud DNS.
          |||,
          query='avg(time() - max_over_time(external_dns_controller_last_reconcile_timestamp_seconds{environment="$environment"}[$__interval])) by (region, cluster)',
          legendFormat='{{ cluster }} ({{ region }}))',
          format='short',
        ),
        panel.timeSeries(
          title='Sync Lag',
          description=|||
            Time since the last sync from Kubernetes sources.
          |||,
          query='avg(time() - avg_over_time(external_dns_controller_last_sync_timestamp_seconds{environment="$environment"}[$__interval])) by (region, cluster)',
          legendFormat='{{ cluster }} ({{ region }}))',
          format='short',
        ),
        panel.timeSeries(
          title='Source Errors',
          description=|||
            Error rate while syncing from Kubernetes sources.
          |||,
          query='sum(rate(external_dns_source_errors_total{environment="$environment"}[$__interval])) by (region, cluster)',
          legendFormat='{{ cluster }} ({{ region }}))',
          format='short',
        ),
        panel.timeSeries(
          title='Registry Errors',
          description=|||
            Error rate while reconciling with GCP Cloud DNS.
          |||,
          query='sum(rate(external_dns_registry_errors_total{environment="$environment"}[$__interval])) by (region, cluster)',
          legendFormat='{{ cluster }} ({{ region }}))',
          format='short',
        ),
      ],
      cols=2,
      rowHeight=10,
      startRow=1,
    ),
  ),
  gridPos={ x: 0, y: 300, w: 24, h: 1 },
)
.overviewTrailer()
