local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local commonDefinition = {
  title: 'Redis Client Utilization per Node',
  severity: 's3',
  horizontallyScalable: false,
  description: |||
    Redis client utilization per node.

    A redis server has a maximum number of clients that can connect. When this resource is saturated,
    new clients may fail to connect.

    More details at https://redis.io/topics/clients#maximum-number-of-clients
  |||,
  resourceLabels: ['fqdn', 'instance', 'shard'],
  query: |||
    max_over_time(redis_connected_clients{%(selector)s}[%(rangeInterval)s])
    /
    redis_config_maxclients{%(selector)s}
  |||,
  slos: {
    soft: 0.80,
    hard: 0.90,
  },
};

{
  redis_clients: resourceSaturationPoint(commonDefinition {
    appliesTo: metricsCatalog.findServicesWithTag(tag='redis-sentinel'),
    grafana_dashboard_uid: 'sat_redis_clients',
  }),

  redis_cluster_clients: resourceSaturationPoint(commonDefinition {
    appliesTo: metricsCatalog.findServicesWithTag(tag='redis-cluster'),
    grafana_dashboard_uid: 'sat_redis_cluster_clients',
    horizontallyScalable: true,
  }),
}
