local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  // Default Runway SLIs
  runwayArchetype(
    type='ext-pvs',
    team='authorization',
    apdexScore=0.999,
    errorRatio=0.999,
    apdexSatisfiedThreshold='4052.650622296292',
    trafficCessationAlertConfig=true,
    severity='s2',
    externalLoadBalancer=false,
    customToolingLinks=[],
  )
)
