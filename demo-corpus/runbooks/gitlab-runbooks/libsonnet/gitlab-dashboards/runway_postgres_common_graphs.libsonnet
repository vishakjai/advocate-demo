local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local row = grafana.row;
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

{
  connectionPanels(serviceType, startRow)::
    local formatConfig = {
      selector: selectors.serializeHash({
        environment: '$environment',
        type: serviceType,
      }),
    };

    local panels = layout.grid(
      [
        panel.timeSeries(
          title='Connections per database',
          description='The number of connections held by the database instance.',
          yAxisLabel='Connections per database',
          query=|||
            max by (database) (stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_num_backends{%(selector)s})
          ||| % formatConfig,
          legendFormat='{{ database }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Connections by status',
          description='The number of connections grouped by these statuses: idle, active, idle_in_transaction, idle_in_transaction_aborted, disabled, and fastpath_function_call.',
          yAxisLabel='Connections by status',
          query=|||
            sum by (state) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_num_backends_by_state{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ state }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Connection wait events',
          description='The number of connections for each wait event type in a Cloud SQL for PostgreSQL instance.',
          yAxisLabel='Wait events',
          query=|||
            sum by (wait_event, wait_event_type) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_backends_in_wait{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ wait_event }} {{ wait_event_type }}',
          interval='30s',
          intervalFactor=1,
        ),
      ],
      cols=3,
      rowHeight=10,
      startRow=startRow + 1,
    );

    layout.titleRowWithPanels(
      title='Connections',
      collapse=true,
      startRow=startRow,
      panels=panels,
    ),

  diskPanels(serviceType, startRow)::
    local formatConfig = {
      selector: selectors.serializeHash({
        environment: '$environment',
        type: serviceType,
      }),
    };

    local panels = layout.grid(
      [
        panel.timeSeries(
          title='Disk read operations',
          description='The Number of Reads metric indicates the number of read operations served from disk that do not come from cache.',
          yAxisLabel='Disk read operations',
          query=|||
            sum by (database_id) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_disk_read_ops_count{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ database_id }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Disk write operations',
          description='The Number of Writes metric indicates the number of write operations to disk.',
          yAxisLabel='Disk write operations',
          query=|||
            sum by (database_id) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_disk_write_ops_count{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ database_id }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Disk storage by type',
          description='The breakdown of instance disk usage by data types, including data, binlog, and tmp_data.',
          yAxisLabel='Disk storage by type',
          query=|||
            sum by (database_id, data_type) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_disk_bytes_used_by_data_type{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ data_type }}',
          interval='30s',
          intervalFactor=1,
          format='bytes'
        ),
      ],
      cols=3,
      rowHeight=10,
      startRow=startRow + 1,
    );

    layout.titleRowWithPanels(
      title='Disk',
      collapse=true,
      startRow=startRow,
      panels=panels,
    ),

  networkPanels(serviceType, startRow)::
    local formatConfig = {
      selector: selectors.serializeHash({
        environment: '$environment',
        type: serviceType,
      }),
    };

    local panels = layout.grid(
      [
        panel.networkTrafficGraph(
          title='Ingress bytes received',
          description='The network traffic in terms of the number of ingress bytes (bytes received) to the instance.',
          receiveQuery=|||
            sum by (database_id) (
              rate(
                stackdriver_cloudsql_database_cloudsql_googleapis_com_database_network_received_bytes_count{%(selector)s}[$__rate_interval]
              )
            ) / 60
          ||| % formatConfig,
          legendFormat='{{database_id}}',
        ),
        panel.networkTrafficGraph(
          title='Egress bytes sent',
          description='The network traffic in terms of the number of egress bytes (bytes sent) from the instance.',
          sendQuery=|||
            sum by (database_id) (
              rate(
                stackdriver_cloudsql_database_cloudsql_googleapis_com_database_network_sent_bytes_count{%(selector)s}[$__rate_interval]
              )
            ) / 60
          ||| % formatConfig,
          legendFormat='{{database_id}}',
        ),
      ],
      cols=2,
      rowHeight=10,
      startRow=startRow + 1,
    );

    layout.titleRowWithPanels(
      title='Network',
      collapse=true,
      startRow=startRow,
      panels=panels,
    ),

  tuplePanels(serviceType, startRow)::
    local formatConfig = {
      selector: selectors.serializeHash({
        environment: '$environment',
        type: serviceType,
      }),
    };

    local charts =
      [
        panel.timeSeries(
          title='Rows fetched',
          description='Rows fetched is the number of rows fetched as a result of queries in the instance.',
          yAxisLabel='Rows fetched',
          query=|||
            sum by (database) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_tuples_fetched_count{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ database }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Rows returned',
          description='Rows returned is the number of rows scanned while processing the queries in the instance.',
          yAxisLabel='Rows returned',
          query=|||
            sum by (database) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_tuples_returned_count{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ database }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Rows written',
          description='Rows written is the number of rows written in the instance while performing insert, update, and delete operations.',
          yAxisLabel='Rows written',
          query=|||
            sum by (database) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_tuples_processed_count{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ database }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Rows Processed by operation',
          description='The number of rows processed per operation per second.',
          yAxisLabel='Rows Processed by operation',
          query=|||
            sum by (database_id, operation_type) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_tuples_processed_count{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ operation_type }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Rows in database by state',
          description='The number of rows for each database state.',
          yAxisLabel='Rows in database by state',
          query=|||
            sum by (database_id, tuple_state) (
              stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_tuple_size{%(selector)s}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ tuple_state }}',
          interval='30s',
          intervalFactor=1,
        ),
      ];

    layout.titleRowWithPanels(
      title='Tuples',
      collapse=true,
      startRow=startRow,
      panels=layout.grid(charts, cols=3, rowHeight=10, startRow=startRow + 1),
    ),

  runwayPostgresDashboard(service)::
    serviceDashboard.overview(
      service,
      includeStandardEnvironmentAnnotations=false
    )
    .addPanels(self.connectionPanels(serviceType=service, startRow=1000))
    .addPanels(self.diskPanels(serviceType=service, startRow=2000))
    .addPanels(self.networkPanels(serviceType=service, startRow=3000))
    .addPanels(self.tuplePanels(serviceType=service, startRow=4000)),
}
