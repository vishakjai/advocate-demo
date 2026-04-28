local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

metricsCatalog.serviceDefinition({
  type: 'elasticache',
  tier: 'db',
  tags: [],

  provisioning: {
    vms: false,
    kubernetes: false,
  },

  serviceLevelIndicators: {
    // No SLIs for now
  },
})
