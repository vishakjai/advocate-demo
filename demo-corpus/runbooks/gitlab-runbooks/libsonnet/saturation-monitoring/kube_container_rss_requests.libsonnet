local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local selectors = import 'promql/selectors.libsonnet';
local excludedShards = std.set(['gitaly-throttled']);

local commonDefinition = {
  title: 'Kube Container Memory Utilization (RSS)',
  severity: 's4',
  horizontallyScalable: false,
  appliesTo: std.filter(
    function(service) service != 'sidekiq',
    metricsCatalog.findServicesWithTag(tag='kube_container_rss')
  ),

  description: |||
    Records the total anonymous (unevictable) memory utilization for containers for this
    service, as a percentage of the memory request as configured through Kubernetes.

    This is computed using the container's resident set size (RSS), as opposed to
    kube_container_memory which uses the working set size. For our purposes, RSS is the
    better metric as cAdvisor's working set calculation includes pages from the
    filesystem cache that can (and will) be evicted before the OOM killer kills the
    cgroup.

    A container's RSS (anonymous memory usage) is still not precisely what the OOM
    killer will use, but it's a better approximation of what the container's workload is
    actually using. RSS metrics can, however, be dramatically inflated if a process in
    the container uses MADV_FREE (lazy-free) memory. RSS will include the memory that is
    available to be reclaimed without a page fault, but not currently in use.

    The most common case of OOM kills is for anonymous memory demand to overwhelm the
    container's memory request. On swapless hosts, anonymous memory cannot be evicted from
    the page cache, so when a container's memory usage is mostly anonymous pages, the
    only remaining option to relieve memory pressure may be the OOM killer.

    As container RSS approaches container memory request, OOM kills become much more
    likely. Consequently, this ratio is a good leading indicator of memory saturation
    and OOM risk.
  |||,
  grafana_dashboard_uid: 'sat_kube_container_rss_request',
  burnRatePeriod: '1h',
  quantileAggregation: 0.99,
  capacityPlanning: {
    saturation_dimension_dynamic_lookup_query: |||
      count by(deployment) (
        last_over_time(container_memory_rss:labeled{deployment!="", %(selector)s}[1w:1d] @ end())
      )
    |||,
    saturation_dimension_dynamic_lookup_limit: 100,
    strategy: 'quantile99_1h',
  },
  resourceLabels: ['pod', 'container', 'deployment'],
  query: |||
    (
      container_memory_rss:labeled{container!="", container!="POD", %(selector)s}
      unless on(pod) (
        kube_pod_labels:labeled{label_gitlab_com_exclude_saturation_point=~"(^|.*[.])kube_container_rss_request([.].*|$)", %(selector)s}
      )
    )
    / on(%(aggregationLabels)s) group_left()
    max by(%(aggregationLabels)s) (
      kube_pod_container_resource_requests:labeled{container!="", resource="memory", %(selector)s} > 0
    )
  |||,
  slos: {
    soft: 0.80,
    hard: 0.90,
    alertTriggerDuration: '15m',
  },
};

local sidekiqDefinition = commonDefinition {
  title: 'Sidekiq Kube Container Memory Utilization (RSS)',
  appliesTo: ['sidekiq'],
  grafana_dashboard_uid: 'sat_sidekiq_kube_cnt_rss_req',
  query: |||
    (
      container_memory_rss:labeled{container!="", container!="POD", %(shardSelector)s, %(selector)s}
      unless on(pod) (
        kube_pod_labels:labeled{label_gitlab_com_exclude_saturation_point=~"(^|.*[.])kube_container_rss_request([.].*|$)", %(selector)s}
      )
    )
    / on(%(aggregationLabels)s) group_left()
    max by(%(aggregationLabels)s) (
      kube_pod_container_resource_requests:labeled{container!="", resource="memory", %(shardSelector)s, %(selector)s} > 0
    )
  |||,
  queryFormatConfig: {
    shardSelector: selectors.serializeHash({ shard: { noneOf: excludedShards } }),
  },
  capacityPlanning: {
    saturation_dimension_dynamic_lookup_query: |||
      count by(deployment) (
        last_over_time(container_memory_rss:labeled{deployment!="", %(shardSelector)s, %(selector)s}[1w:1d] @ end())
      )
    |||,
    saturation_dimension_dynamic_lookup_limit: 100,
    strategy: 'quantile99_1h',
  },
};

local excludedSidekiqDefinition = commonDefinition {
  title: 'Excluded Sidekiq Kube Container Memory Utilization (RSS)',
  appliesTo: ['sidekiq'],
  grafana_dashboard_uid: 'excl_sat_sidekiq_kube_cnt_rss_req',
  query: |||
    (
      container_memory_rss:labeled{container!="", container!="POD", %(shardSelector)s, %(selector)s}
      unless on(pod) (
        kube_pod_labels:labeled{label_gitlab_com_exclude_saturation_point=~"(^|.*[.])kube_container_rss_request([.].*|$)", %(selector)s}
      )
    )
    / on(%(aggregationLabels)s) group_left()
    max by(%(aggregationLabels)s) (
      kube_pod_container_resource_requests:labeled{container!="", resource="memory", %(shardSelector)s, %(selector)s} > 0
    )
  |||,
  queryFormatConfig: {
    shardSelector: selectors.serializeHash({ shard: excludedShards }),
  },
  capacityPlanning: {
    strategy: 'exclude',
  },
};

{
  kube_container_rss_request: resourceSaturationPoint(commonDefinition),
  sidekiq_kube_container_rss_request: resourceSaturationPoint(sidekiqDefinition),
  excluded_sidekiq_kube_container_rss_request: resourceSaturationPoint(excludedSidekiqDefinition),
}
