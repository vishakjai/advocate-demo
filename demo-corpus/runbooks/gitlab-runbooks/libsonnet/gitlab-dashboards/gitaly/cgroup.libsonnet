local quantilePanel = import 'grafana/quantile_panel.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local repoCgroupPattern = '/gitaly/gitaly-[0-9]+/repos-[0-9]+';

{
  CPUUsagePerCGroup(selectorHash)::
    panel.timeSeries(
      title='cgroup: CPU per cgroup',
      description='Rate of CPU usage on every cgroup available on the Gitaly node.',
      query=|||
        topk(20, sum by (id) (rate(container_cpu_usage_seconds_total{%(selector)s}[$__interval])))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      format='percentunit',
      interval='1m',
      linewidth=1,
      legendFormat='{{ id }}',
      legend_show=false,
    ),

  CPUThrottling(selectorHash)::
    panel.timeSeries(
      title='cgroup: CPU Throttling',
      description='Cgroups that are getting CPU throttled. If the cgroup is not visible it is not getting throttled.',
      query=|||
        rate(
          container_cpu_cfs_throttled_seconds_total{%(selector)s}[$__rate_interval]
        ) > 0
      ||| % { selector: selectors.serializeHash(selectorHash) },
      interval='1m',
      linewidth=1,
      legendFormat='{{ id }}',
    ),

  MemoryUsageBytes(title, filterRepoCgroups, selectorHash)::
    local filteredSelectorHash =
      if filterRepoCgroups then
        selectorHash { id: { re: repoCgroupPattern } }
      else
        selectorHash { id: { nre: repoCgroupPattern } };
    panel.timeSeries(
      title=title,
      description=|||
        This metric reflects usage_in_bytes (V1) or memory.current (V2) of cgroups on the Gitaly node. This metric consists of Anonymous Memory + Page Caches + Swap + some Kernel Memory.
        Gitaly triggers a massive amount of Git processes accessing files on disk. This usage pattern accumulating Page Caches in repository cgroups and inflate the parent cgroup's usage bytes. A huge portion of page caches could be evictable. Hence, the usage bytes peaking doesn't mean the system is overloaded. Working set metric (Usage Bytes - Inactive File) is a more accurate signal for memory pressure.

        For more information, please this comment: https://gitlab.com/groups/gitlab-org/-/epics/10734#note_1632048830
      |||,
      query=|||
        topk(20, sum by (id) (container_memory_usage_bytes{%(selector)s}))
      ||| % { selector: selectors.serializeHash(filteredSelectorHash) },
      format='bytes',
      interval='1m',
      linewidth=1,
      legendFormat='{{ id }}',
      legend_show=false,
    ),

  MemoryWorkingSetBytes(title, filterRepoCgroups, selectorHash)::
    local filteredSelectorHash =
      if filterRepoCgroups then
        selectorHash { id: { re: repoCgroupPattern } }
      else
        selectorHash { id: { nre: repoCgroupPattern } };
    panel.timeSeries(
      title=title,
      description=|||
        This metric reflects usage_in_bytes (V1) or memory.current (V2) excluding inactive_file. There are two types of Page Caches in cgroup: active_file and inactive_file. inactive_file are Page Caches which have been moved off the active LRU list. When the cgroup has a memory pressure, they are targeted for eviction first. In contrast, active_file descibres the portion of the memory which has been accessed recently. Gitaly usage pattern accesses Page Caches a lot. So, active page caches are essential for the overall performance; we should not evict them. Thus, the working set metric excludes highly evictable memory portion it acts as a more accurate signal for memory pressure.
      |||,
      query=|||
        topk(20, sum by (id) (container_memory_working_set_bytes{%(selector)s}))
      ||| % { selector: selectors.serializeHash(filteredSelectorHash) },
      format='bytes',
      interval='1m',
      linewidth=1,
      legendFormat='{{ id }}',
      legend_show=false,
    ),

  MemoryCacheBytes(title, filterRepoCgroups, selectorHash)::
    local filteredSelectorHash =
      if filterRepoCgroups then
        selectorHash { id: { re: repoCgroupPattern } }
      else
        selectorHash { id: { nre: repoCgroupPattern } };
    panel.timeSeries(
      title=title,
      description=|||
        This metric reflects cache (V1) or file (V2) in memory.state. It's the total page caches accounted for a cgroup.

        Page cache accounting is complicated. Any page created by a process inside a cgroup is accounted for by that cgroup. If the page already exists in memory, the page will eventually get accounted to the cgroup after it keeps accessing that page aggressively. And those pages are also counted in the ancestor cgroup. With the current Gitaly's cgroup architecture, the parent per-pid cgroup accounts for all page caches of its indirect processes.

        If the parent cgroup keeps accumulating Page Caches, it evicts them constantly when direct/indirect processes needs allocation (denoted by failcnt metric).
      |||,
      query=|||
        topk(20, sum by (id) (container_memory_cache{%(selector)s}))
      ||| % { selector: selectors.serializeHash(filteredSelectorHash) },
      format='bytes',
      interval='1m',
      linewidth=1,
      legendFormat='{{ id }}',
      legend_show=false,
    ),

  MemoryFailcnt(title, selectorHash)::
    panel.timeSeries(
      title=title,
      description=|||
        This metric reflects the changes of failcnt counter. It denotes how frequent the cgroup needs to evict memory. The name is misleading, it's more a "GC" counter than failure counter. After a eviction, if the cgroup cannot find enough spaces for allocation, OOM Killer is invoked.
      |||,
      query=|||
        sum by (id) (increase(container_memory_failcnt{%(selector)s}[$__interval])) > 0
      ||| % { selector: selectors.serializeHash(selectorHash) },
      interval='1m',
      linewidth=1,
      legend_show=false,
      legendFormat='{{ id }}',
    ),
}
