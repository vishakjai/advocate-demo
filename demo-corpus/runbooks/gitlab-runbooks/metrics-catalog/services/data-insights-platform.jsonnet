local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local rateMetric = metricsCatalog.rateMetric;

metricsCatalog.serviceDefinition({
  type: 'data-insights-platform',
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

    local dipWorkloadSelector = { container: { re: 'data-insights-platform-.*' } },

    ingester: {
      team: 'platform_insights',
      serviceAggregation: true,
      userImpacting: false,
      significantLabels: [],
      // TODO: determine feature category
      // featureCategory:
      severity: 's3',
      description: |||
        Data Insights platform Ingestor is responsible for ingesting events generated across Gitlab.
      |||,

      requestRate: rateMetric(
        counter='raw_ingestion_http_requests_total',
        selector=dipWorkloadSelector,
      ),

      errorRate: rateMetric(
        counter='raw_ingestion_http_requests_total',
        selector=dipWorkloadSelector {
          code: { re: '^5.*' },
        },
      ),
      toolingLinks: [
        toolingLinks.kibana(title='Data Insights Platform', index='analytics_eventsdot'),
      ],
    },
  },
  skippedMaturityCriteria: {
    'Service exists in the dependency graph': 'Data Insights Platform is an independent component',
  },
})
