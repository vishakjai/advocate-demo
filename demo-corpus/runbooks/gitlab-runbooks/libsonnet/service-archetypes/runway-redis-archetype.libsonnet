local redisArchetype = import 'service-archetypes/redis-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

function(
  type,
  descriptiveName,
  featureCategory='not_owned',
  redisCluster=false,
)
  redisArchetype(type, descriptiveName, featureCategory, redisCluster)
  {
    tenants: ['runway'],
    provisioning: {
      runway: true,
      vms: false,
      kubernetes: false,
    },
    // The shard label refers to the regions since runway redis can be multi-region.
    // We monitor each region as a shard.
    monitoring: { shard: { enabled: true } },
    tags: [
      // Do not include 'redis' tag for now since we are directly using stackdriver metrics.
      // See https://gitlab.com/gitlab-com/gl-infra/platform/runway/team/-/issues/406
      // Note that because this is a managed redis, we do not have finer grain node stats.
      'runway-managed-redis',
    ],
    serviceLevelIndicators: {
      primary_server: {
        apdexSkip: 'apdex for redis is measured clientside',
        userImpacting: true,
        featureCategory: featureCategory,
        serviceAggregation: false,
        shardLevelMonitoring: true,
        description: |||
          Operations on the Redis primary for Runway managed memorystore instances.
        |||,
        requestRate: metricsCatalog.gaugeMetric(
          gauge='stackdriver_redis_instance_redis_googleapis_com_commands_calls',
          selector={ type: type },
          samplingInterval=60,  //seconds. See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-redis
        ),

        significantLabels: ['instance'],

        toolingLinks: [],
      },
    },
    skippedMaturityCriteria+: {
      'Structured logs available in Kibana': 'GCP-managed Memorystore Redis does not have kibana logs',
      'Service exists in the dependency graph': 'For now, no service is depending on this the redis service',
    },
  }
