local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  // Default Runway SLIs
  runwayArchetype(
    type='secret-revc-worker',
    team='secret_detection',
    featureCategory='secret_detection',
    trafficCessationAlertConfig=false,
    externalLoadBalancer=false,  // service will no longer be publicly accessible
    userImpacting=false
  )
)
