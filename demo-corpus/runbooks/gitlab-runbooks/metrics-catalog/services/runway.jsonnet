local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local gaugeMetric = metricsCatalog.gaugeMetric;

metricsCatalog.serviceDefinition({
  type: 'runway',
  tier: 'inf',
  tenants: ['runway'],

  monitoringThresholds: {
    apdexScore: 0.99,
    errorRatio: 0.99,
  },

  regional: false,

  provisioning: {
    vms: false,
    kubernetes: false,
  },

  serviceDependencies: {
    vault: true,
    'ci-runners': true,
  },

  serviceIsStageless: true,

  serviceLevelIndicators: {},

  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'Runway is a platform. The logs are available in Stackdriver.',
  },
})
