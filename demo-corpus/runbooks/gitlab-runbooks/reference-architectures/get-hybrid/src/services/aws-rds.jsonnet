local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

metricsCatalog.serviceDefinition({
  type: 'rds',
  tier: 'db',
  tags: ['gitlab_monitor_bloat', 'postgres_vacuum_monitoring'],

  provisioning: {
    vms: false,
    kubernetes: false,
  },

  serviceLevelIndicators: {
    // No SLIs for now
  },
})
