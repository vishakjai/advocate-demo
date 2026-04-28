local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  // Default Runway SLIs
  runwayArchetype(
    type='secret-detection',
    team='secret_detection',
    featureCategory='secret_detection',
    externalLoadBalancer=false  // The service is not public facing and is accessible only to Rails monolith
  )
)
