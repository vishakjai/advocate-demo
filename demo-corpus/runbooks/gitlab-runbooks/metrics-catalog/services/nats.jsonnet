local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local rateMetric = metricsCatalog.rateMetric;

metricsCatalog.serviceDefinition({
  type: 'nats',
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
    local natsWorkloadSelector = { container: 'prom-exporter' },

    server: {
      team: 'platform_insights',
      serviceAggregation: true,
      userImpacting: false,
      significantLabels: [],
      // TODO: determine feature category
      // featureCategory:
      severity: 's3',
      description: |||
        NATS is responsible for buffering of events generated across Gitlab.
      |||,

      requestRate: rateMetric(
        counter='nats_varz_in_msgs',
        selector=natsWorkloadSelector,
      ),

      errorRate: rateMetric(
        counter='nats_varz_slow_consumers',
        selector=natsWorkloadSelector
      ),
      toolingLinks: [
        toolingLinks.kibana(title='Data Insights Platform', index='analytics_eventsdot'),
      ],
    },

    jetstream: {
      team: 'platform_insights',
      serviceAggregation: true,
      userImpacting: false,
      significantLabels: [],
      // TODO: determine feature category
      // featureCategory:
      severity: 's3',
      description: |||
        JetStream provides persistent message streaming for event processing across GitLab.
      |||,

      requestRate: rateMetric(
        counter='nats_stream_total_messages',
        selector=natsWorkloadSelector,
      ),

      errorRate: rateMetric(
        counter='nats_consumer_num_redelivered',
        selector=natsWorkloadSelector,
      ),
      toolingLinks: [
        toolingLinks.kibana(title='Data Insights Platform', index='analytics_eventsdot'),
      ],
    },
  },
  skippedMaturityCriteria: {
    'Service exists in the dependency graph': 'NATS is an independent component',
  },
})
