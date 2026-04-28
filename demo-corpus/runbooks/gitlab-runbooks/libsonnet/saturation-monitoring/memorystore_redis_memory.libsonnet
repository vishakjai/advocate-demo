local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

local prodRedisInstances = ['memorystore-redis-tracechunks'];

{
  memorystore_redis_memory: resourceSaturationPoint({
    title: 'Memorystore Memory Utilization',
    severity: 's4',
    horizontallyScalable: false,
    appliesTo: std.filter(function(s) !std.member(prodRedisInstances, s), metricsCatalog.findServicesWithTag(tag='memorystore-redis')) + metricsCatalog.findServicesWithTag(tag='runway-managed-redis'),
    description: |||
      Memorystore Redis memory utilization.

      See https://cloud.google.com/memorystore/docs/redis/monitor-instances#create-stackdriver-alert
    |||,
    grafana_dashboard_uid: 'sat_memorystore_redis_memory',
    resourceLabels: [],
    burnRatePeriod: '5m',
    staticLabels: {
      tier: 'inf',
      stage: 'main',
    },
    query: |||
      max by (%(aggregationLabels)s) (
        stackdriver_redis_instance_redis_googleapis_com_stats_memory_usage_ratio{%(selector)s, role = "primary"}
      )
    |||,
    slos: {
      soft: 0.50,
      hard: 0.60,
    },
  }),
  memorystore_redis_memory_tracechunks: resourceSaturationPoint({
    title: 'Memorystore Memory Utilization',
    severity: 's2',
    horizontallyScalable: false,
    appliesTo: prodRedisInstances,
    description: |||
      Memorystore Redis memory utilization.

      As Redis memory saturates node memory, the likelyhood of OOM kills, possibly to the Redis process,
      become more likely.

      Trace chunks should be extremely transient (written to redis, then offloaded to objectstorage nearly immediately)
      so any uncontrolled growth in memory saturation implies a potentially significant problem.  Short term mitigation
      is usually to upsize the instances to have more memory while the underlying problem is identified, but low
      thresholds give us more time to investigate first

      This threshold is kept deliberately very low; because we use C2 instances we are generally overprovisioned
      for RAM, and because of the transient nature of the data here, it is advantageous to know early if there is any
      non-trivial storage occurring

      See https://cloud.google.com/memorystore/docs/redis/monitor-instances#create-stackdriver-alert
    |||,
    grafana_dashboard_uid: 'sat_redis_memory_tracechunk',
    resourceLabels: [],
    burnRatePeriod: '5m',
    staticLabels: {
      tier: 'inf',
      stage: 'main',
    },
    query: |||
      max by (%(aggregationLabels)s) (
        stackdriver_redis_instance_redis_googleapis_com_stats_memory_usage_ratio{%(selector)s, role = "primary"}
      )
    |||,
    slos: {
      // Intentionally very low, maybe able to go lower.  See description above
      soft: 0.40,
      hard: 0.50,
    },
  }),
}
