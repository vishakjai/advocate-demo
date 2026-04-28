local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local memoryUsage() =
  panel.timeSeries(
    title='Memory usage by instance',
    legendFormat='{{instance}}',
    format='percentunit',
    linewidth=2,
    query=|||
      instance:node_memory_utilization:ratio{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"}
    |||,
  );

local cpuUsage() =
  panel.timeSeries(
    title='CPU usage by instance',
    legendFormat='{{instance}}',
    format='percentunit',
    linewidth=2,
    query=|||
      instance:node_cpu_utilization:ratio{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"}
    |||,
  );

local fdsUsage() =
  panel.timeSeries(
    title='File Descriptiors usage by instance',
    legendFormat='{{instance}}',
    format='percentunit',
    linewidth=2,
    query=|||
      process_open_fds{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}",job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner"}
      /
      process_max_fds{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}",job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner"}
    |||,
  );

local diskAvailable() =
  panel.timeSeries(
    title='Disk available by instance and device',
    legendFormat='{{instance}} - {{device}}',
    format='percentunit',
    linewidth=2,
    query=|||
      instance:node_filesystem_avail:ratio{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}",fstype="ext4"}
    |||,
  );

local iopsUtilization() =
  panel.multiTimeSeries(
    title='IOPS',
    format='ops',
    linewidth=2,
    queries=[
      {
        legendFormat: '{{instance}} - writes',
        query: |||
          instance:node_disk_writes_completed:irate1m{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"}
        |||,
      },
      {
        legendFormat: '{{instance}} - reads',
        query: |||
          instance:node_disk_reads_completed:irate1m{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"}
        |||,
      },
    ],
  ) + {
    seriesOverrides+: [
      {
        alias: '/reads/',
        transform: 'negative-Y',
      },
    ],
  };

local networkUtilization() =
  panel.multiTimeSeries(
    title='Network Utilization',
    format='bps',
    linewidth=2,
    queries=[
      {
        legendFormat: '{{instance}} - sent',
        query: |||
          sum by (instance) (
            rate(node_network_transmit_bytes_total{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"}[$__rate_interval])
          )
        |||,
      },
      {
        legendFormat: '{{instance}} - received',
        query: |||
          sum by (instance) (
            rate(node_network_receive_bytes_total{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"}[$__rate_interval])
          )
        |||,
      },
    ],
  ) + {
    seriesOverrides+: [
      {
        alias: '/received/',
        transform: 'negative-Y',
      },
    ],
  };

{
  memoryUsage:: memoryUsage,
  cpuUsage:: cpuUsage,
  fdsUsage:: fdsUsage,
  diskAvailable:: diskAvailable,
  iopsUtilization:: iopsUtilization,
  networkUtilization:: networkUtilization,
}
