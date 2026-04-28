local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local redisHelpers = import './lib/redis-helpers.libsonnet';
local findServicesWithTag = (import 'servicemetrics/metrics-catalog.libsonnet').findServicesWithTag;

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-cluster-database-lb',
    railsStorageSelector=redisHelpers.storageSelector('db_load_balancing'),
    descriptiveName='Redis DB load balancing in Redis Cluster',
    redisCluster=true
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
    monitoringThresholds+: {
      apdexScore: 0.9999,
    },
    serviceLevelIndicators+: {
      rails_redis_client+: {
        userImpacting: true,
      },
      primary_server+: {
        userImpacting: true,
      },
      secondary_servers+: {
        userImpacting: true,
      },
    },
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-cluster-database-lb')
)
