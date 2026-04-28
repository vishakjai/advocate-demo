local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local commonDefinition = {
  title: 'Redis Primary CPU Utilization per Node',
  severity: 's1',
  horizontallyScalable: false,
  description: |||
    Redis Primary CPU Utilization per Node.

    The core server of redis is single-threaded; this thread is only able to scale to full use of a single CPU on a given server.
    When the primary Redis thread is saturated, major slowdowns should be expected across the application, so avoid if at all
    possible.
  |||,
  resourceLabels: ['fqdn', 'instance', 'shard'],
  burnRatePeriod: '5m',
  query: |||
    sum by (%(aggregationLabels)s) (
      rate(
        namedprocess_namegroup_thread_cpu_seconds_total{%(selector)s, groupname="redis-server", threadname="redis-server"}[%(rangeInterval)s])
    )
    and on (fqdn) redis_instance_info{role="master"}
  |||,
  slos: {
    soft: 0.85,
    hard: 0.95,
  },
};

{
  redis_primary_cpu: resourceSaturationPoint(commonDefinition {
    appliesTo: metricsCatalog.findServicesWithTag(tag='redis-sentinel'),
    grafana_dashboard_uid: 'sat_redis_primary_cpu',

    capacityPlanning: {
      forecast_days: 180,
      changepoint_range: 0.98,
    },
  }),

  redis_cluster_primary_cpu: resourceSaturationPoint(commonDefinition {
    appliesTo: metricsCatalog.findServicesWithTag(tag='redis-cluster'),
    grafana_dashboard_uid: 'sat_redis_cluster_primary_cpu',
    horizontallyScalable: true,

    capacityPlanning: {
      forecast_days: 180,
      changepoint_range: 0.98,
    },
  }),
}
