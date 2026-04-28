local redisHelpers = import './lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-actioncable',
    railsStorageSelector=redisHelpers.storageSelector('action_cable'),
    descriptiveName='Redis that handles predominantly Rails ActionCable operations',
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-actioncable')
  + {
    provisioning+: {
      kubernetes: false,
      vms: true,
    },
  }
)
