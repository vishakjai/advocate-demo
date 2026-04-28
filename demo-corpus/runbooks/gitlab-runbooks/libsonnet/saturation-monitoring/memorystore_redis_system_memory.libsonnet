local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  memorystore_system_memory: resourceSaturationPoint({
    title: 'Memorystore System Memory Utilization',
    severity: 's4',
    horizontallyScalable: false,
    appliesTo: metricsCatalog.findServicesWithTag(tag='runway-managed-redis') + metricsCatalog.findServicesWithTag(tag='memorystore-redis'),
    description: |||
      Memorystore Redis system memory utilization.

      See https://cloud.google.com/memorystore/docs/redis/monitor-instances#system-memory-stackdriver-alert
    |||,
    grafana_dashboard_uid: 'sat_memorystore_system_memory',
    resourceLabels: [],
    burnRatePeriod: '5m',
    staticLabels: {
      tier: 'inf',
      stage: 'main',
    },
    query: |||
      max by (%(aggregationLabels)s) (
        stackdriver_redis_instance_redis_googleapis_com_stats_memory_system_memory_usage_ratio{%(selector)s, role = "primary"}
      )
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
