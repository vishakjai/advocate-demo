local postgresArchetype = import 'service-archetypes/runway-postgres-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  postgresArchetype(
    type='runway-db-example',
    descriptiveName='Example Postgres managed by Runway'
  )
)
