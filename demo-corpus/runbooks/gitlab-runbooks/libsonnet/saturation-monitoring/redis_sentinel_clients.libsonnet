local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local commonDefinition = {
  title: 'Redis Sentinel Client Utilization per Node',
  severity: 's3',
  horizontallyScalable: false,
  description: |||
    Redis sentinel client utilization per node.

    A redis sentinel has a maximum number of clients that can connect. When this resource is saturated,
    new clients may fail to connect redis server because "Sentinel is both responsible for reconfiguring
    instances during failovers, and providing configurations to clients connecting to Redis masters or replicas" per docs.

    More details at https://redis.io/docs/latest/develop/reference/sentinel-clients/
  |||,
  resourceLabels: ['fqdn', 'instance', 'shard'],
  query: |||
    max_over_time(gitlab_redis_sentinel_connected_clients{%(selector)s}[%(rangeInterval)s])
    /
    gitlab_redis_sentinel_maxclients{%(selector)s}
  |||,
  slos: {
    soft: 0.80,
    hard: 0.90,
  },
};

{
  redis_sentinel_clients: resourceSaturationPoint(commonDefinition {
    appliesTo: metricsCatalog.findServicesWithTag(tag='redis-sentinel'),
    grafana_dashboard_uid: 'sat_redis_sentinel_clients',
  }),
}
