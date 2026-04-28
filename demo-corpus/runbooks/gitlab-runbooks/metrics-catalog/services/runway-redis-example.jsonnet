local redisArchetype = import 'service-archetypes/runway-redis-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='runway-redis-example',
    descriptiveName='Example Redis managed by Runway'
  ) {
    serviceLevelIndicators+: {
      primary_server+: {
        userImpacting: false,
        severity: 's4',
      },
    },
  }
)
