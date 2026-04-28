local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;

metricsCatalog.serviceDefinition(
  // Default Runway SLIs
  runwayArchetype(
    type='secrets-manager',
    team='pipeline_security',
    featureCategory='secrets_management'
  )
  // Custom OpenBao SLIs
  {
    serviceLevelIndicators+: {
      openbao_requests: {
        userImpacting: true,
        featureCategory: 'secrets_management',
        requestRate: rateMetric(
          counter='secrets_manager_openbao_core_handle_request_count'
        ),
        significantLabels: [],
      },
    },
  }
)
