local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local memorystoreRedisArchetype = import 'service-archetypes/memorystore-redis-rails-archetype.libsonnet';
local redisHelpers = import './lib/redis-helpers.libsonnet';

metricsCatalog.serviceDefinition(
  memorystoreRedisArchetype(
    type='memorystore-redis-tracechunks',
    railsStorageSelector=redisHelpers.storageSelector('trace_chunks'),
    descriptiveName='Memorystore for Redis instance for TraceChunks',
    featureCategory='continuous_integration',
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
    monitoringThresholds+: {
      apdexScore: 0.9999,
    },
    serviceLevelIndicators+: {
      rails_redis_client+: {
        description: |||
          Aggregation of all Memorystore Redis Tracechunks operations issued from the Rails codebase.

          If this SLI is experiencing a degradation then the output of CI jobs may be delayed in becoming visible or in severe situations the data may be lost.
        |||,
      },
    },
  }
)
