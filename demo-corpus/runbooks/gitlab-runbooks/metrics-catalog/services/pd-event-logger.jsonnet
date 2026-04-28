local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  runwayArchetype(
    type='pd-event-logger-7760xa',
    team='sre_reliability',
    trafficCessationAlertConfig=false,
  )
)
