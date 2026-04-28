local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  memorystore_redis_cpu: resourceSaturationPoint({
    title: 'Memorystore CPU Utilization',
    severity: 's4',
    horizontallyScalable: false,
    appliesTo: metricsCatalog.findServicesWithTag(tag='runway-managed-redis') + metricsCatalog.findServicesWithTag(tag='memorystore-redis'),
    description: |||
      Memorystore Redis CPU utilization.

      See https://cloud.google.com/memorystore/docs/redis/general-best-practices#cpu_usage_best_practices for more details
    |||,
    grafana_dashboard_uid: 'sat_memorystore_redis_cpu',
    resourceLabels: [],
    burnRatePeriod: '5m',
    staticLabels: {
      tier: 'inf',
      stage: 'main',
    },
    query: |||
      sum by (%(aggregationLabels)s)
      (
        stackdriver_redis_instance_redis_googleapis_com_stats_cpu_utilization_main_thread{%(selector)s, role='primary'}
      ) / 60
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
