local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local redisArchetype = import 'service-archetypes/redis-archetype.libsonnet';
local redisHelpers = import './lib/redis-helpers.libsonnet';
local registryBaseSelector = {
  type: 'registry',
};
local registryRateLimitingSelector = registryBaseSelector {
  exported_instance: 'ratelimiting',
};

local registryDbLoadBalancingSelector = registryBaseSelector {
  exported_instance: 'loadbalancing',
};

local registryCacheBaseSelector = registryBaseSelector {
  exported_instance: 'cache',
};

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-cluster-registry',
    descriptiveName='Redis Cluster Registry',
    redisCluster=true
  )
  {
    monitoringThresholds+: {
      apdexScore: 0.9995,
    },
    serviceLevelIndicators+: {
      registry_ratelimiting_redis_client: {
        userImpacting: false,
        severity: 's3',
        description: |||
          Aggregation of all container registry Redis operations.
        |||,

        apdex: histogramApdex(
          histogram='registry_redis_single_commands_bucket',
          selector=registryRateLimitingSelector,
          satisfiedThreshold=0.25,
          toleratedThreshold=0.5
        ),

        requestRate: rateMetric(
          counter='registry_redis_single_commands_count',
          selector=registryRateLimitingSelector
        ),

        errorRate: rateMetric(
          counter='registry_redis_single_errors_count',
          selector=registryRateLimitingSelector
        ),

        emittedBy: ['registry'],

        significantLabels: ['instance', 'command'],
      },
      registry_db_loadbalancing_redis_client: {
        userImpacting: false,
        severity: 's3',
        description: |||
          Aggregation of all container registry Redis operations.
        |||,

        apdex: histogramApdex(
          histogram='registry_redis_single_commands_bucket',
          selector=registryDbLoadBalancingSelector,
          satisfiedThreshold=0.25,
          toleratedThreshold=0.5
        ),

        requestRate: rateMetric(
          counter='registry_redis_single_commands_count',
          selector=registryDbLoadBalancingSelector
        ),

        errorRate: rateMetric(
          counter='registry_redis_single_errors_count',
          selector=registryDbLoadBalancingSelector
        ),

        emittedBy: ['registry'],

        significantLabels: ['instance', 'command'],
      },
      registry_cache_redis_client: {
        userImpacting: false,
        severity: 's3',
        description: |||
          Aggregation of all container registry Redis operations.
        |||,

        apdex: histogramApdex(
          histogram='registry_redis_single_commands_bucket',
          selector=registryCacheBaseSelector,
          satisfiedThreshold=0.25,
          toleratedThreshold=0.5
        ),

        requestRate: rateMetric(
          counter='registry_redis_single_commands_count',
          selector=registryCacheBaseSelector
        ),

        errorRate: rateMetric(
          counter='registry_redis_single_errors_count',
          selector=registryCacheBaseSelector
        ),

        emittedBy: ['registry'],

        significantLabels: ['instance', 'command'],
      },
    },
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-cluster-registry')
)
