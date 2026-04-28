local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

// HACK: containers running Go
// Ideally we shouldn't need to keep this updated manually
local goContainers = ['gitlab-pages', 'gitlab-workhorse', 'kas', 'registry'];

{
  kube_go_memory: resourceSaturationPoint({
    title: 'Go Memory Utilization per Node',
    severity: 's4',
    dangerouslyThanosEvaluated: true,
    burnRatePeriod: '1h',
    quantileAggregation: 0.99,
    capacityPlanning: {
      strategy: 'quantile99_1h',
    },
    horizontallyScalable: true,
    appliesTo: std.setInter(
      std.set(metricsCatalog.findServicesWithTag(tag='golang')),
      std.set(metricsCatalog.findKubeProvisionedServices())
    ),
    description: |||
      Measures Go memory usage as a percentage of container memory request
    |||,
    grafana_dashboard_uid: 'sat_kube_go_memory',
    resourceLabels: ['cluster', 'pod'],
    queryFormatConfig: {
      goContainers: std.join('|', goContainers),
    },
    query: |||
      go_memstats_alloc_bytes{%(selector)s}
      / on(%(aggregationLabels)s) group_left()
      max by(%(aggregationLabels)s) (
        kube_pod_container_resource_requests:labeled{container=~"%(goContainers)s", resource="memory", %(selector)s}
      )
    |||,
    slos: {
      soft: 0.90,
      hard: 0.98,
    },
  }),
}
