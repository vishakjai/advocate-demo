local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  runwayArchetype(
    type='engineering-portal',
    team='proj-engineering-portal',
    trafficCessationAlertConfig=false,
    userImpacting=false,
    severity='s4',
    externalLoadBalancer=true
  )
)
