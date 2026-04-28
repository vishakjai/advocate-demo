local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  runwayArchetype(
    type='spamcheck',
    team='authorization_spamcheck',
    apdexScore=0.999,
    errorRatio=0.999,
    trafficCessationAlertConfig=true,
  )
)
