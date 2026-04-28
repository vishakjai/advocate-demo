local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local nodeMetrics = import 'gitlab-dashboards/node_metrics.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local saturationDetail = import 'gitlab-dashboards/saturation_detail.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local metricsCatalogDashboards = import 'gitlab-dashboards/metrics_catalog_dashboards.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local processExporter = import 'gitlab-dashboards/process_exporter.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local singleMetricRow = import 'key-metric-panels/single-metric-row.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local gitalyCommandStats = import 'gitlab-dashboards/gitaly/command_stats.libsonnet';
local gitalyPackObjectsDashboards = import 'gitlab-dashboards/gitaly/pack_objects.libsonnet';
local gitalyPerRPCDashboards = import 'gitlab-dashboards/gitaly/per_rpc.libsonnet';
local gitalyAdaptiveLimitDashboards = import 'gitlab-dashboards/gitaly/adaptive_limit.libsonnet';
local gitalyCgroupDashboards = import 'gitlab-dashboards/gitaly/cgroup.libsonnet';
local gitalyBackupDashboards = import 'gitlab-dashboards/gitaly/backup.libsonnet';
local gitalyRaftDashboards = import 'gitlab-dashboards/gitaly/raft.libsonnet';
local gitalyHousekeepingDashboards = import 'gitlab-dashboards/gitaly/housekeeping.libsonnet';

local serviceType = 'gitaly';

local inflightGitalyCommandsPerNode(selector) =
  panel.timeSeries(
    title='Inflight Git Commands on Node',
    description='Number of Git commands running concurrently per node. Lower is better.',
    query=|||
      avg_over_time(gitaly_commands_running{%(selector)s}[$__interval])
    ||| % { selector: selector },
    legendFormat='{{ fqdn }}',
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local oomKillsPerNode(selector) =
  panel.timeSeries(
    title='OOM Kills on Node',
    description='Number of OOM Kills per server.',
    query=|||
      increase(node_vmstat_oom_kill{%(selector)s}[$__interval])
    ||| % { selector: selector },
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local gitalySpawnTimeoutsPerNode(selector) =
  panel.timeSeries(
    title='Gitaly Spawn Timeouts per Node',
    description='Golang uses a global lock on process spawning. In order to control contention on this lock Gitaly uses a safety valve. If a request is unable to obtain the lock within a period, a timeout occurs. These timeouts are serious and should be addressed. Non-zero is bad.',
    query=|||
      increase(gitaly_spawn_timeouts_total{%(selector)s}[$__interval])
    ||| % { selector: selector },
    legendFormat='{{ fqdn }}',
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local gitalySpawnTokenQueueLengthPerNode(selector) =
  panel.timeSeries(
    title='Gitaly Spawn Token queue length per Node',
    query=|||
      sum(gitaly_spawn_token_waiting_length{%(selector)s}) by (fqdn)
    ||| % { selector: selector },
    legendFormat='{{ fqdn }}',
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local gitalySpawnTokenForkingTimePerNode(selector) =
  panel.timeSeries(
    title='Gitaly Spawn Token P99 forking time per Node',
    query=|||
      histogram_quantile(0.99, sum(rate(gitaly_spawn_forking_time_seconds_bucket{%(selector)s}[$__interval])) by (le))
    ||| % { selector: selector },
    format='s',
    legendFormat='{{ fqdn }}',
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local gitalySpawnTokenWaitingTimePerNode(selector) =
  panel.timeSeries(
    title='Gitaly Spawn Token P99 waiting time per Node',
    query=|||
      histogram_quantile(0.99, sum(rate(gitaly_spawn_waiting_time_seconds_bucket{%(selector)s}[$__interval])) by (le))
    ||| % { selector: selector },
    format='s',
    legendFormat='{{ fqdn }}',
    interval='1m',
    linewidth=1,
    legend_show=false,
  );

local selectorHash = {
  environment: '$environment',
  env: '$environment',
  type: 'gitaly',
  fqdn: { re: '$fqdn' },
};
local selectorSerialized = selectors.serializeHash(selectorHash);

local headlineRow(startRow=1) =
  local metricsCatalogServiceInfo = metricsCatalog.getService('gitaly');
  local formatConfig = { serviceType: serviceType };
  local selectorHashWithExtras = selectorHash { type: serviceType };

  local columns =
    singleMetricRow.row(
      serviceType='gitaly',
      sli=null,
      aggregationSet=aggregationSets.nodeServiceSLIs,
      selectorHash=selectorHashWithExtras,
      titlePrefix='Gitaly Per-Node Service Aggregated SLIs',
      stableIdPrefix='node-latency-%(serviceType)s' % formatConfig,
      legendFormatPrefix='',
      showApdex=metricsCatalogServiceInfo.hasApdex(),
      showErrorRatio=metricsCatalogServiceInfo.hasErrorRate(),
      showOpsRate=true,
    );
  layout.splitColumnGrid(columns, [7, 1], startRow=startRow);

basic.dashboard(
  'Host Detail',
  tags=['type:gitaly'],
)
.addTemplate(templates.fqdn(query='gitlab_build_info{type="gitaly", git_version!="", environment="$environment"}', current='file-01-stor-gprd.c.gitlab-production.internal'))
.addPanels(
  headlineRow(startRow=100)
)
.addPanels(
  metricsCatalogDashboards.sliMatrixForService(
    title='🔬 Node SLIs',
    aggregationSet=aggregationSets.nodeComponentSLIs,
    serviceType='gitaly',
    selectorHash=selectorHash,
    startRow=200,
  )
)
.addPanel(
  metricsCatalogDashboards.sliDetailMatrix(
    'gitaly',
    'goserver',
    selectorHash,
    [
      { title: 'Overall', aggregationLabels: '', selector: {}, legendFormat: 'goserver' },
    ],
  ), gridPos={ x: 0, y: 2000 }
)
.addPanel(nodeMetrics.nodeMetricsDetailRow(selectorHash), gridPos={ x: 0, y: 3000 })
.addPanel(
  saturationDetail.saturationDetailPanels(
    selectorHash,
    components=[
      'cgroup_memory',
      'cpu',
      'disk_space',
      'disk_sustained_read_iops',
      'disk_sustained_read_throughput',
      'disk_sustained_write_iops',
      'disk_sustained_write_throughput',
      'memory',
      'open_fds',
      'single_node_cpu',
      'go_memory',
    ],
  ),
  gridPos={ x: 0, y: 4000, w: 24, h: 1 }
)
.addPanel(
  row.new(title='Node Performance', collapse=true).addPanels(
    layout.grid([
      inflightGitalyCommandsPerNode(selectorSerialized),
      oomKillsPerNode(selectorSerialized),
    ], startRow=5001),
  ),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  },
)
.addPanel(
  row.new(title='gitaly spawn tokens', collapse=true)
  .addPanels(
    layout.grid([
      gitalySpawnTimeoutsPerNode(selectorSerialized),
      gitalySpawnTokenQueueLengthPerNode(selectorSerialized),
      gitalySpawnTokenWaitingTimePerNode(selectorSerialized),
      gitalySpawnTokenForkingTimePerNode(selectorSerialized),
    ], startRow=5101)
  ),
  gridPos={
    x: 0,
    y: 5100,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly process activity', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'gitaly processes',
      selectorHash
      {
        groupname: { re: 'gitaly' },
      },
      aggregationLabels=[],
      startRow=5201,
    )
  ),
  gridPos={
    x: 0,
    y: 5200,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='git process activity', collapse=true)
  .addPanels(
    processExporter.namedGroup(
      'git processes',
      selectorHash
      {
        groupname: { re: 'git.*' },
      },
      aggregationLabels=['groupname'],
      startRow=5301,
    )
  ),
  gridPos={
    x: 0,
    y: 5300,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly command stats by command', collapse=true)
  .addPanels(
    gitalyCommandStats.metricsForNode(
      selectorHash,
      includeDetails=false,
      aggregationLabels=['cmd', 'subcmd'],
      startRow=5501,
    )
  ),
  gridPos={
    x: 0,
    y: 5500,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly command stats by RPC', collapse=true)
  .addPanels(
    gitalyCommandStats.metricsForNode(
      selectorHash,
      includeDetails=false,
      aggregationLabels=['grpc_service', 'grpc_method'],
      startRow=5601,
    )
  ),
  gridPos={
    x: 0,
    y: 5600,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly command stats by commands per RPC', collapse=true)
  .addPanels(
    gitalyCommandStats.metricsForNode(
      selectorHash,
      aggregationLabels=['grpc_method', 'cmd', 'subcmd'],
      startRow=5701,
    )
  ),
  gridPos={
    x: 0,
    y: 5700,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly per-RPC metrics', collapse=true)
  .addPanels(
    layout.grid([
      gitalyAdaptiveLimitDashboards.per_rpc_current_limit(selectorHash, '{{ limit }}'),
      gitalyPerRPCDashboards.request_rate_by_method(selectorHash),
      gitalyPerRPCDashboards.request_rate_by_code(selectorHash),
      gitalyPerRPCDashboards.in_progress_requests(selectorHash),
      gitalyPerRPCDashboards.queued_requests(selectorHash),
      gitalyPerRPCDashboards.queueing_time(selectorHash),
      gitalyPerRPCDashboards.dropped_requests(selectorHash),
    ], startRow=5802)
  ),
  gridPos={
    x: 0,
    y: 5800,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='gitaly pack-objects metrics', collapse=true)
  .addPanels(
    layout.grid([
      gitalyAdaptiveLimitDashboards.pack_objects_current_limit(selectorHash, '{{ limit }}'),
      gitalyPackObjectsDashboards.in_process(selectorHash, 'concurrency by gitaly process'),
      gitalyPackObjectsDashboards.queued_commands(selectorHash, 'queued commands'),
      gitalyPackObjectsDashboards.queueing_time(selectorHash, '95th queueing time'),
      gitalyPackObjectsDashboards.dropped_commands(selectorHash, '{{ reason }}'),
      gitalyPackObjectsDashboards.cache_served(selectorHash, 'cache served'),
      gitalyPackObjectsDashboards.cache_generated(selectorHash, 'cache generated'),
      gitalyPackObjectsDashboards.cache_lookup(selectorHash, '{{ result }}'),
      gitalyPackObjectsDashboards.pack_objects_info(),
    ], startRow=5902)
  ),
  gridPos={
    x: 0,
    y: 5900,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='cgroup', collapse=true)
  .addPanels(
    layout.grid([
      gitalyCgroupDashboards.CPUUsagePerCGroup(selectorHash),
      gitalyCgroupDashboards.CPUThrottling(selectorHash),
      gitalyCgroupDashboards.MemoryUsageBytes('cgroup: Memory usage bytes (parent cgroups)', false, selectorHash),
      gitalyCgroupDashboards.MemoryUsageBytes('cgroup: Top usage bytes (repository cgroups)', true, selectorHash),
      gitalyCgroupDashboards.MemoryWorkingSetBytes('cgroup: Memory working set bytes (parent cgroups)', false, selectorHash),
      gitalyCgroupDashboards.MemoryWorkingSetBytes('cgroup: Top working set bytes (repository cgroups)', true, selectorHash),
      gitalyCgroupDashboards.MemoryCacheBytes('cgroup: Memory cache bytes (parent cgroups)', false, selectorHash),
      gitalyCgroupDashboards.MemoryCacheBytes('cgroup: Top cache bytes (repository cgroups)', true, selectorHash),
      gitalyCgroupDashboards.MemoryFailcnt('cgroup: failcnt', selectorHash),
      oomKillsPerNode(selectorSerialized),
      basic.text(
        title='cgroup runbook',
        content=|||
          Gitaly spawns git processes into cgroups to limit their cpu and memory
          usage. This is to cap the maximum amount of cpu/memory used by a single
          git process and hence affecting other processes on the same host.
          This helps in fair usage of system resources among all
          the repositories hosted by a single Gitaly storage server.

          Here is the runbook to debug issues related to Gitaly cgroups:
          https://runbooks.gitlab.com/gitaly/gitaly-repos-cgroup/
        |||
      ),
    ], startRow=6001)
  ),
  gridPos={
    x: 0,
    y: 6000,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='Adaptive limit metrics', collapse=true)
  .addPanels(
    layout.grid([
      gitalyAdaptiveLimitDashboards.backoff_events(selectorHash, '{{ watcher }}'),
      gitalyAdaptiveLimitDashboards.watcher_errors(selectorHash, '{{ watcher }}'),
    ], startRow=7001)
  ),
  gridPos={
    x: 0,
    y: 7000,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='Server-side backup metrics', collapse=true)
  .addPanels(
    layout.grid([
      gitalyBackupDashboards.backup_duration(selectorHash),
      gitalyBackupDashboards.backup_rpc_status(selectorHash),
      gitalyBackupDashboards.backup_rpc_latency(selectorHash),
      gitalyBackupDashboards.backup_bundle_upload_rate(selectorHash),
    ], startRow=8001)
  ),
  gridPos={
    x: 0,
    y: 8000,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='Housekeeping metrics', collapse=true)
  .addPanels(
    layout.grid([
      gitalyHousekeepingDashboards.performed_optimizations(selectorHash),
      gitalyHousekeepingDashboards.housekeeping_failures(selectorHash),
      gitalyHousekeepingDashboards.per_optimization_latencies(selectorHash),
      gitalyHousekeepingDashboards.accumulated_optimization_timings(selectorHash),
      gitalyHousekeepingDashboards.time_since_last_optimization(selectorHash),
    ], startRow=8101)
  ),
  gridPos={
    x: 0,
    y: 8100,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='Housekeeping datastructure metrics', collapse=true)
  .addPanels(
    layout.grid([
      gitalyHousekeepingDashboards.stale_file_pruning(selectorHash),
      gitalyHousekeepingDashboards.data_structure_existence(selectorHash),
    ] + gitalyHousekeepingDashboards.data_structure_heatmaps(selectorHash), startRow=8201)
  ),
  gridPos={
    x: 0,
    y: 8200,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='Raft metrics', collapse=true)
  .addPanels(
    layout.grid([
      gitalyRaftDashboards.event_loop_crashes(selectorHash, '{{ storage }}'),
      gitalyRaftDashboards.log_entries_processed(selectorHash, '{{ storage }} - {{ operation }} - {{ entry_type }}'),
      gitalyRaftDashboards.proposals_rate(selectorHash, '{{ storage }} - {{ result }}'),
      gitalyRaftDashboards.proposal_queue_depth(selectorHash, '{{ storage }}'),
      gitalyRaftDashboards.proposal_duration(selectorHash, '{{ storage }}'),
      gitalyRaftDashboards.snapshot_duration(selectorHash, '{{ storage }}'),
      gitalyRaftDashboards.warning_panel(),
    ], startRow=9001)
  ),
  gridPos={
    x: 0,
    y: 9000,
    w: 24,
    h: 1,
  }
)
.trailer()
+ {
  links+: platformLinks.triage + platformLinks.services +
          [platformLinks.dynamicLinks('Gitaly Detail', 'type:gitaly')],
}
