local basic = import 'runbooks/libsonnet/grafana/basic.libsonnet';
local panel = import 'runbooks/libsonnet/grafana/time-series/panel.libsonnet';
local selectors = import 'runbooks/libsonnet/promql/selectors.libsonnet';

local cpuUsage(selector) =
  panel.timeSeries(
    title='CPU Usage',
    query=|||
      (
        (1 - sum without (mode) (rate(node_cpu_seconds_total{mode=~"idle|iowait|steal", %(selector)s}[$__rate_interval])))
        / ignoring(cpu) group_left
        count without (cpu, mode) (node_cpu_seconds_total{mode="idle", %(selector)s})
      )
    ||| % { selector: selector },
    format='percentunit',
    fill=10,
    min=0,
    max=1,
    stack=true,
    stableId='node-cpu-usage'
  );

local loadAverage(selector) =
  panel.multiTimeSeries(
    title='Load Average',
    queries=[
      {
        query: 'node_load1{%(selector)s}' % { selector: selector },
        legendFormat: '1m load average',
      },
      {
        query: 'node_load5{%(selector)s}' % { selector: selector },
        legendFormat: '5m load average',
      },
      {
        query: 'node_load15{%(selector)s}' % { selector: selector },
        legendFormat: '15m load average',
      },
      {
        query: 'count(node_cpu_seconds_total{%(selector)s, mode="idle"})' % { selector: selector },
        legendFormat: 'logical cores',
      },
    ],
    format='short',
    min=0,
    fill=0,
    stableId='node-load-average'
  );

local memoryUsage(selector) =
  panel.multiTimeSeries(
    title='Memory Usage',
    queries=[
      {
        query: |||
          (
            node_memory_MemTotal_bytes{%(selector)s}
            -
            node_memory_MemFree_bytes{%(selector)s}
            -
            node_memory_Buffers_bytes{%(selector)s}
            -
            node_memory_Cached_bytes{%(selector)s}
          )
        ||| % { selector: selector },
        legendFormat: 'memory used',
      },
      {
        query: 'node_memory_Buffers_bytes{%(selector)s}' % { selector: selector },
        legendFormat: 'memory buffers',
      },
      {
        query: 'node_memory_Cached_bytes{%(selector)s}' % { selector: selector },
        legendFormat: 'memory cached',
      },
      {
        query: 'node_memory_MemFree_bytes{%(selector)s}' % { selector: selector },
        legendFormat: 'memory free',
      },
    ],
    format='bytes',
    min=0,
    fill=10,
    stack=true,
    stableId='node-memory-usage'
  );

local memoryUsageGauge(selector) =
  basic.statPanel(
    title='Memory Usage',
    panelTitle='Memory Usage',
    query=|||
      100 -
      (
        avg(node_memory_MemAvailable_bytes{%(selector)s}) /
        avg(node_memory_MemTotal_bytes{%(selector)s})
        * 100
      )
    ||| % { selector: selector },
    unit='percent',
    min=0,
    max=100,
    color=[
      { color: 'green', value: null },
      { color: 'orange', value: 80 },
      { color: 'red', value: 90 },
    ],
    graphMode='gauge',
    stableId='node-memory-usage-gauge',
  );

local diskIO(selector) =
  panel.multiTimeSeries(
    title='Disk I/O',
    queries=[
      {
        query: 'rate(node_disk_read_bytes_total{%(selector)s, device=~"(/dev/)?(mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|md.+|dasd.+)"}[$__rate_interval])' % { selector: selector },
        legendFormat: '{{device}} read',
      },
      {
        query: 'rate(node_disk_written_bytes_total{%(selector)s, device=~"(/dev/)?(mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|md.+|dasd.+)"}[$__rate_interval])' % { selector: selector },
        legendFormat: '{{device}} written',
      },
      {
        query: 'rate(node_disk_io_time_seconds_total{%(selector)s, device=~"(/dev/)?(mmcblk.p.+|nvme.+|rbd.+|sd.+|vd.+|xvd.+|dm-.+|md.+|dasd.+)"}[$__rate_interval])' % { selector: selector },
        legendFormat: '{{device}} io time',
      },
    ],
    format='Bps',
    fill=0,
    stableId='node-disk-io'
  );

local diskSpaceUsage(selector) =
  panel.timeSeries(
    title='Disk Space Usage',
    description='Disk space usage per mount point',
    query=|||
      max by (mountpoint) (
        node_filesystem_size_bytes{%(selector)s, fstype!="", mountpoint!=""} -
        node_filesystem_avail_bytes{%(selector)s, fstype!="", mountpoint!=""}
      )
      /
      max by (mountpoint) (
        node_filesystem_size_bytes{%(selector)s, fstype!="", mountpoint!=""}
      )
    ||| % { selector: selector },
    legendFormat='{{mountpoint}}',
    format='percentunit',
    min=0,
    max=1,
    stableId='node-disk-space-usage'
  );

local networkReceived(selector) =
  panel.timeSeries(
    title='Network Received',
    description='Network received (bits/s)',
    query='rate(node_network_receive_bytes_total{%(selector)s, device!~"lo|docker"}[$__rate_interval]) * 8' % { selector: selector },
    legendFormat='{{device}}',
    format='bps',
    min=0,
    stableId='node-network-received'
  );

local networkTransmitted(selector) =
  panel.timeSeries(
    title='Network Transmitted',
    description='Network transmitted (bits/s)',
    query='rate(node_network_transmit_bytes_total{%(selector)s, device!~"lo|docker"}[$__rate_interval]) * 8' % { selector: selector },
    legendFormat='{{device}}',
    format='bps',
    min=0,
    stableId='node-network-transmitted'
  );

{
  new(selectorHash):: {
    local selector = selectors.serializeHash(selectorHash),

    cpuUsage:: cpuUsage(selector),
    loadAverage:: loadAverage(selector),
    memoryUsage:: memoryUsage(selector),
    memoryUsageGauge:: memoryUsageGauge(selector),
    diskIO:: diskIO(selector),
    diskSpaceUsage:: diskSpaceUsage(selector),
    networkReceived:: networkReceived(selector),
    networkTransmitted:: networkTransmitted(selector),
  },
}
