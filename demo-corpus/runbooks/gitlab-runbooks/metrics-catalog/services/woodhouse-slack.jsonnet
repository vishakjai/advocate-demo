local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  runwayArchetype(
    type='woodhouse-slack',
    team='sre_reliability',
    trafficCessationAlertConfig=false,
  )
)
