local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  kube_container_rss_limit: resourceSaturationPoint({
    title: 'Kube Container Memory Over-Utilization (RSS)',
    severity: 's4',
    horizontallyScalable: false,
    appliesTo: metricsCatalog.findServicesWithTag(tag='kube_container_rss'),
    description: |||
      Records the total anonymous (unevictable) memory utilization for containers for this
      service, as a percentage of the memory limit as configured through Kubernetes.

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
      container's memory limit. On swapless hosts, anonymous memory cannot be evicted from
      the page cache, so when a container's memory usage is mostly anonymous pages, the
      only remaining option to relieve memory pressure may be the OOM killer.

      As container RSS goes over the container memory request and approaches
      container memory limit, OOM kills become much more likely. Consequently,
      this ratio is a good leading indicator of memory saturation and OOM risk.
    |||,
    grafana_dashboard_uid: 'sat_kube_container_rss_limit',
    burnRatePeriod: '5m',
    capacityPlanning: { strategy: 'exclude' },
    resourceLabels: ['pod', 'container', 'deployment'],
    query: |||
      (
        container_memory_rss:labeled{container!="", container!="POD", %(selector)s}
        unless on(pod) (
          kube_pod_labels:labeled{label_gitlab_com_exclude_saturation_point=~"(^|.*[.])kube_container_rss_limit([.].*|$)", %(selector)s}
        )
      )
      / on(%(aggregationLabels)s) group_left()
      max by(%(aggregationLabels)s) (
        kube_pod_container_resource_limits:labeled{container!="", resource="memory", %(selector)s} > 0
      )
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
      alertTriggerDuration: '15m',
    },
  }),
}
