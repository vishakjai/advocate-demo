local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local threshold = import 'grafana/time-series/threshold.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local override = import 'grafana/time-series/override.libsonnet';

local nodeLoadForDuration(duration, nodeSelector) =
  assert (duration == 1 || duration == 5 || duration == 15) : 'Load duration needs to be 1, 5 or 15';
  local formatConfigWithDuration = {
    duration: duration,
    nodeSelector: selectors.serializeHash(nodeSelector),
  };

  panel.timeSeries(
    title='loadavg%(duration)d per core' % formatConfigWithDuration,
    description='Loadavg (%(duration)d minute) per core, below 1 is better.' % formatConfigWithDuration,
    query=
    |||
      avg by (environment, type, stage, fqdn) (node_load%(duration)d{%(nodeSelector)s})
      /
      count by (environment, type, stage, fqdn) (node_cpu_seconds_total{mode="idle", %(nodeSelector)s})
    ||| % formatConfigWithDuration,
    legendFormat='{{ fqdn }}',
    interval='1m',
    intervalFactor=1,
    yAxisLabel='loadavg%(duration)d' % formatConfigWithDuration,
    legend_show=false,
    linewidth=1,
    thresholdMode='percentage',
    thresholdSteps=[
      threshold.errorLevel(100),
      threshold.warningLevel(80),
    ]
  );

{
  nodeMetricsDetailRow(nodeSelector, title='🖥️ Node Metrics')::
    local formatConfig = {
      nodeSelector: selectors.serializeHash(nodeSelector),
    };
    row.new(title, collapse=true)
    .addPanels(layout.grid(
      [
        panel.basic(
          'Node CPU',
          description='The amount of non-idle time consumed by nodes for this service',
          legend_show=false,
          legend_alignAsTable=false,
          unit='percentunit'
        )
        .addTarget(  // Primary metric
          target.prometheus(
            |||
              avg(instance:node_cpu_utilization:ratio{%(nodeSelector)s}) by (fqdn)
            ||| % formatConfig,
            legendFormat='{{ fqdn }}',
            intervalFactor=1,
          )
        )
        .addYaxis(
          label='Average CPU Utilization',
        ),
        panel.saturationTimeSeries(
          'Node Maximum Single Core Utilization',
          description='The maximum utilization of a single core on each node. Lower is better',
          query=
          |||
            max(1 - rate(node_cpu_seconds_total{%(nodeSelector)s, mode="idle"}[$__interval])) by (fqdn)
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          legend_show=false,
          linewidth=1
        ),
        panel.basic(
          'Node Network Utilization',
          description='Network utilization for nodes for this service',
          legend_show=false,
          legend_alignAsTable=false,
          unit='Bps',
        )
        .addSeriesOverride(override.networkReceive)
        .addTarget(
          target.prometheus(
            |||
              sum(rate(node_network_transmit_bytes_total{%(nodeSelector)s}[$__interval])) by (fqdn)
            ||| % formatConfig,
            legendFormat='send {{ fqdn }}',
            intervalFactor=1,
          )
        )
        .addTarget(
          target.prometheus(
            |||
              sum(rate(node_network_receive_bytes_total{%(nodeSelector)s}[$__interval])) by (fqdn)
            ||| % formatConfig,
            legendFormat='receive {{ fqdn }}',
            intervalFactor=1,
          )
        )
        .addYaxis(
          label='Network utilization',
        ),
        panel.saturationTimeSeries(
          title='Memory Utilization',
          description='Memory utilization. Lower is better.',
          query=
          |||
            instance:node_memory_utilization:ratio{%(nodeSelector)s}
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          interval='1m',
          intervalFactor=1,
          legend_show=false,
          linewidth=1
        ),
        // Node-level disk metrics
        // Reads on the left, writes on the right
        //
        // IOPS ---------------
        panel.timeSeries(
          title='Disk Read IOPs',
          description='Disk Read IO operations per second. Lower is better.',
          query=
          |||
            max(
              rate(node_disk_reads_completed_total{%(nodeSelector)s}[$__interval])
            ) by (fqdn)
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          format='ops',
          interval='1m',
          intervalFactor=1,
          yAxisLabel='Operations/s',
          legend_show=false,
          linewidth=1
        ),
        panel.timeSeries(
          title='Disk Write IOPs',
          description='Disk Write IO operations per second. Lower is better.',
          query=
          |||
            max(
              rate(node_disk_writes_completed_total{%(nodeSelector)s}[$__interval])
            ) by (fqdn)
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          format='ops',
          interval='1m',
          intervalFactor=1,
          yAxisLabel='Operations/s',
          legend_show=false,
          linewidth=1
        ),
        // Disk Throughput ---------------
        panel.timeSeries(
          title='Disk Read Throughput',
          description='Disk Read throughput datarate. Lower is better.',
          query=
          |||
            max(
              rate(node_disk_read_bytes_total{%(nodeSelector)s}[$__interval])
            ) by (fqdn)
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          format='Bps',
          interval='1m',
          intervalFactor=1,
          yAxisLabel='Bytes/s',
          legend_show=false,
          linewidth=1
        ),
        panel.timeSeries(
          title='Disk Write Throughput',
          description='Disk Write throughput datarate. Lower is better.',
          query=
          |||
            max(
              rate(node_disk_written_bytes_total{%(nodeSelector)s}[$__interval])
            ) by (fqdn)
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          format='Bps',
          interval='1m',
          intervalFactor=1,
          yAxisLabel='Bytes/s',
          legend_show=false,
          linewidth=1
        ),
        // Disk Total Time ---------------
        panel.timeSeries(
          title='Disk Read Total Time',
          description='Total time spent in read operations across all disks on the node. Lower is better.',
          query=
          |||
            sum(
              rate(node_disk_read_time_seconds_total{%(nodeSelector)s}[$__interval])
            ) by (fqdn)
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          format='s',
          interval='30s',
          intervalFactor=1,
          yAxisLabel='Total Time/s',
          legend_show=false,
          linewidth=1
        ),
        panel.timeSeries(
          title='Disk Write Total Time',
          description='Total time spent in write operations across all disks on the node. Lower is better.',
          query=
          |||
            sum(
              rate(node_disk_write_time_seconds_total{%(nodeSelector)s}[$__interval])
            ) by (fqdn)
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          format='s',
          interval='30s',
          intervalFactor=1,
          yAxisLabel='Total Time/s',
          legend_show=false,
          linewidth=1
        ),
        panel.timeSeries(
          title='CPU Scheduling Waiting',
          description='CPU scheduling waiting on the run queue, as a percentage of time. Aggregated to worst CPU per node. Lower is better.',
          query=
          |||
            max by (fqdn) (
              rate(node_schedstat_waiting_seconds_total{%(nodeSelector)s}[5m])
            )
          ||| % formatConfig,
          legendFormat='{{ fqdn }}',
          format='percentunit',
          interval='1m',
          intervalFactor=1,
          yAxisLabel='Total Time/s',
          legend_show=false,
          linewidth=1,
          thresholdMode='percentage',
          thresholdSteps=[
            threshold.errorLevel(100),
            threshold.warningLevel(0.75),
          ]
        ),

      ] + [
        // Node-level load averages
        (
          nodeLoadForDuration(duration, nodeSelector)
        )
        for duration in [1, 5, 15]
      ]
    )),
  nodeLoadForDuration:: nodeLoadForDuration,
}
