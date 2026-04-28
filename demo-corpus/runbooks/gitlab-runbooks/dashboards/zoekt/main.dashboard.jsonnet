local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local timeseriesGraph(title, query) =
  panel.timeSeries(
    title=title,
    stableId='gitlab-zoekt-%s' % std.asciiLower(title),
    query=query,
  );

local timeseriesGraphWithUnit(title, query, unit) =
  panel.timeSeries(
    title=title,
    stableId='gitlab-zoekt-%s' % std.asciiLower(title),
    query=query,
    format=unit,
  );

local memoryMapUsage() =
  local title = 'Memory Map Usage';
  panel.timeSeries(
    title=title,
    stableId='gitlab-zoekt-%s' % std.asciiLower(title),
    query=|||
      sum(proc_metrics_memory_map_current_count{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"}) by (container, pod)
    |||,
  )
  .addTarget(
    target.prometheus(
      |||
        min(proc_metrics_memory_map_max_limit{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"})
      |||,
      legendFormat='Memory Map Limit'
    )
  )
  .addSeriesOverride({
    alias: 'Memory Map Limit',
    color: 'red',
    dashes: true,
    dashLength: 8,
  });

local cpuUsage() =
  timeseriesGraph(
    title='CPU Usage',
    query=|||
      sum(rate(container_cpu_usage_seconds_total{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"}[5m]))by (container, pod)
    |||,
  );


local cpuThrottling() =
  timeseriesGraph(
    title='CPU Throttling',
    query=|||
      sum(rate(container_cpu_cfs_throttled_seconds_total{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"}[5m]))by (container, pod)
    |||,
  );

local diskUtilization() =
  local title = 'Persistent Volume Disk Utilization';
  panel.timeSeries(
    title=title,
    stableId='gitlab-zoekt-%s' % std.asciiLower(title),
    yAxisLabel='% utilization',
    legendFormat='{{persistentvolumeclaim}}',
    query=|||
      100*sum(kubelet_volume_stats_used_bytes{env="$environment", persistentvolumeclaim=~"zoekt-index-gitlab-gitlab-zoekt.*"}
      / kubelet_volume_stats_capacity_bytes{env="$environment", persistentvolumeclaim=~"zoekt-index-gitlab-gitlab-zoekt.*"}) by (persistentvolumeclaim)
    |||,
  )
  .addTarget(
    target.prometheus('80', legendFormat='80% Threshold')
  )
  .addSeriesOverride({
    alias: '80% Threshold',
    color: 'red',
    dashes: true,
    dashLength: 8,
    stack: true,
  });

local diskReads() =
  timeseriesGraph(
    title='I/O Reads',
    query=|||
      sum(rate(container_fs_reads_bytes_total{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"}[5m])) by (container, pod)
    |||,
  );

local diskWrites() =
  timeseriesGraph(
    title='I/O Writes',
    query=|||
      sum(rate(container_fs_writes_bytes_total{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"}[5m])) by (container, pod)
    |||,
  );

local containerMemoryHeapInUse() =
  timeseriesGraphWithUnit(
    title='Container Heap In Use (bytes)',
    query=|||
      sum(go_memstats_heap_inuse_bytes{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"}) by (container, pod)
    |||,
    unit='bytes',
  );

local containerResidentMemory() =
  timeseriesGraphWithUnit(
    title='Container Resident Memory (bytes)',
    query=|||
      sum(process_resident_memory_bytes{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"}) by (container, pod)
    |||,
    unit='bytes',
  );

local containerMemoryUsage() =
  local title = 'Container Memory Utilization';
  panel.timeSeries(
    title=title,
    stableId='gitlab-zoekt-%s' % std.asciiLower(title),
    yAxisLabel='% utilization',
    legendFormat='{{container}}',
    query=|||
      100*sum(container_memory_working_set_bytes{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"} /container_spec_memory_limit_bytes{pod=~"gitlab-gitlab-zoekt.*", container=~"zoekt.*", env="$environment"}) by (container, pod)
    |||,
  )
  .addTarget(
    target.prometheus('80', legendFormat='80% Threshold')
  )
  .addSeriesOverride({
    alias: '80% Threshold',
    color: 'red',
    dashes: true,
    dashLength: 8,
    stack: true,
  });

local nodesStatus() =
  panel.timeSeries(
    title='Online/Offline status',
    query=|||
      max by (zoekt_node_id) (search_zoekt_nodes_status{environment="$environment"})
    |||,
    description='Node is marked as offline if it remains unavailable for at least 2 minutes.',
  );

local zoektRepositoriesCountWithoutLatestSchemaVersion() =
  panel.timeSeries(
    title='Zoekt repositories count with the schema version less than their node',
    legendFormat='{{zoekt_node_id}}(latest schema version: {{target_schema_version}})',
    query=|||
      sum (search_zoekt_repositories_schema_version_count{environment="$environment"}) by (zoekt_node_id, target_schema_version)
    |||,
    description=|||
      Ideally every zoekt repositories must have the same schema_version as of it's node.
      If a zoekt repository's schema_version is less than node's schema_version that means it is pending to be indexed.
    |||,
  );

serviceDashboard.overview('zoekt')
.overviewTrailer()
.addPanels(
  layout.rowGrid(
    'Disk',
    [
      diskUtilization(),
      diskReads(),
      diskWrites(),

    ],
    startRow=1000,
    collapse=true,
  )
)
.addPanels(
  layout.rowGrid(
    'Memory',
    [
      memoryMapUsage(),
      containerMemoryHeapInUse(),
      containerResidentMemory(),
      containerMemoryUsage(),
    ],
    startRow=2000,
    collapse=true,
  )
)
.addPanels(
  layout.rowGrid(
    'CPU',
    [
      cpuUsage(),
      cpuThrottling(),
    ],
    startRow=3000,
    collapse=true,
  )
)
.addPanels(
  layout.rowGrid(
    'Zoekt Metrics',
    [
      nodesStatus()
      .addYaxis(
        min=0,
        max=1,
        label='Status(Offline(0) | Online(1))',
        show=true,
      ),
      zoektRepositoriesCountWithoutLatestSchemaVersion()
      .addYaxis(
        label='Count of zoekt repositories',
        show=true,
      ),
      panel.timeSeries(
        title='Unclaimed Storage per Zoekt Node',
        stableId='gitlab-zoekt-unclaimed-storage-per-node',
        description='Unclaimed storage bytes available per zoekt node.',
        query='sum by (zoekt_node_id) (search_zoekt_node_unclaimed_storage_bytes{environment="$environment"})',
        legendFormat='{{ zoekt_node_id }}',
        format='bytes'
      ),

      panel.timeSeries(
        title='Storage Percent Used per Zoekt Node',
        stableId='gitlab-zoekt-storage-percent-per-node',
        description='Percentage of storage used per zoekt node (0-1).',
        query='avg by (zoekt_node_id) (search_zoekt_node_storage_percent_used{environment="$environment"})',
        legendFormat='{{ zoekt_node_id }}',
        format='percentunit',
        max=1
      ),
    ],
    startRow=4000,
    collapse=true,
  )
)
