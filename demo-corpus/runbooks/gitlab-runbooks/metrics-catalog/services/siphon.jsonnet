local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local rateMetric = metricsCatalog.rateMetric;

metricsCatalog.serviceDefinition({
  type: 'siphon',
  tier: 'sv',
  tenants: ['analytics-eventsdot'],

  monitoringThresholds: {
    apdexScore: 0.99,
    errorRatio: 0.95,
  },

  provisioning: {
    vms: false,
    kubernetes: true,
  },

  serviceLevelIndicators: {
    local siphonWorkloadSelector = { namespace: 'siphon', cluster: { re: 'orbit-.*' } },

    siphon_producers: {
      team: 'platform_insights',
      serviceAggregation: true,
      userImpacting: false,
      significantLabels: ['app_id'],
      // TODO: determine feature category
      // featureCategory:
      severity: 's2',
      description: |||
        Siphon moves data from postgres to clickhouse
      |||,

      requestRate: rateMetric(
        counter='siphon_operations_total',
        selector=siphonWorkloadSelector,
      ),

      toolingLinks: [
        toolingLinks.kibana(title='Data Insights Platform', index='orbit'),
      ],
    },
    siphon_consumers: {
      team: 'platform_insights',
      serviceAggregation: true,
      userImpacting: false,
      significantLabels: ['product_app_id'],
      // TODO: determine feature category
      // featureCategory:
      severity: 's3',
      description: |||
        Siphon moves data from postgres to clickhouse
      |||,

      requestRate: rateMetric(
        counter='siphon_clickhouse_consumer_number_of_events',
        selector=siphonWorkloadSelector,
      ),

      toolingLinks: [
        toolingLinks.kibana(title='Data Insights Platform', index='orbit'),
      ],
    },
  },
  skippedMaturityCriteria: {
    'Service exists in the dependency graph': 'NATS is an independent component',
  },
})
