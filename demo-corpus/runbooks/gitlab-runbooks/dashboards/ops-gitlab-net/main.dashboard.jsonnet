local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';

local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local row = grafana.row;

local databaseId = 'gitlab-ops:ops-central';

serviceDashboard.overview(
  'ops-gitlab-net',
  showProvisioningDetails=false,
  showSystemDiagrams=false,
  environmentSelectorHash={},
  saturationEnvironmentSelectorHash={},
)
.addPanel(
  row.new(title='💾 CloudSQL', collapse=true)
  .addPanels(
    layout.grid(
      [
        panel.timeSeries(
          title='CPU Utilization',
          description=|||
            CPU utilization.

            See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
            more details.
          |||,
          query='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_cpu_utilization{database_id="%s", environment="ops"} * 100' % databaseId,
          legendFormat='{{ database_id }}',
          format='percent'
        ),
        panel.timeSeries(
          title='Memory Utilization',
          description=|||
            Memory utilization.

            See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
            more details.
          |||,
          query='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_memory_utilization{database_id="%s", environment="ops"} * 100' % databaseId,
          legendFormat='{{ database_id }}',
          format='percent'
        ),
        panel.timeSeries(
          title='Disk Utilization',
          description=|||
            Data utilization in bytes.

            See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
            more details.
          |||,
          query='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_disk_bytes_used{database_id="%s", environment="ops"}' % databaseId,
          legendFormat='{{ database_id }}',
          format='bytes'
        ),
        panel.timeSeries(
          title='Transactions',
          description=|||
            Delta count of number of transactions. Sampled every 60 seconds.

            See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
            more details.
          |||,
          query=|||
            sum by (database_id) (
              avg_over_time(stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_transaction_count{database_id="%s", environment="ops"}[$__interval])
            )
          ||| % databaseId,
          legendFormat='{{ database_id }}',
        ),
      ],
      cols=4,
      rowHeight=10,
      startRow=1000,
    )
  ),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  },
)
.overviewTrailer()
