local redisHelpers = import './lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-pubsub',
    railsStorageSelector=redisHelpers.storageSelector('workhorse'),
    descriptiveName='Redis that handles pub/sub operations that are not ActionCable-related',
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-pubsub')
  + {
    provisioning+: {
      kubernetes: true,
      vms: false,
    },
  }
)
