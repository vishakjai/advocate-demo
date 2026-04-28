local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local redisHelpers = import './lib/redis-helpers.libsonnet';
local findServicesWithTag = (import 'servicemetrics/metrics-catalog.libsonnet').findServicesWithTag;

local railsCacheSelector = redisHelpers.storeSelector('RedisRepositoryCache');

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-cluster-repo-cache',  // name is shortened due to CloudDNS 255 char limits
    railsStorageSelector=redisHelpers.storageSelector('repository_cache'),
    descriptiveName='Redis Repository Cache in Redis Cluster',
    redisCluster=true
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
    monitoringThresholds+: {
      apdexScore: 0.9999,
    },
    serviceLevelIndicators+: {
      rails_cache: {
        userImpacting: true,
        featureCategory: 'not_owned',
        description: |||
          Rails ActiveSupport Cache operations against the Redis Cache
        |||,

        apdex: histogramApdex(
          histogram='gitlab_cache_operation_duration_seconds_bucket',
          selector=railsCacheSelector,
          satisfiedThreshold=0.01,
          toleratedThreshold=0.1
        ),

        requestRate: rateMetric(
          counter='gitlab_cache_operation_duration_seconds_count',
          selector=railsCacheSelector,
        ),

        emittedBy: findServicesWithTag(tag='rails'),

        significantLabels: [],
      },
    },
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-cluster-repo-cache')
)
