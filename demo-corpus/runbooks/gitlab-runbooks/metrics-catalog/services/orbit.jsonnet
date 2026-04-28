local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local rateMetric = metricsCatalog.rateMetric;

metricsCatalog.serviceDefinition({
  type: 'orbit',
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
    local natsWorkloadSelector = { container: 'prom-exporter', cluster: { re: 'orbit-.*' } },

    nats_server: {
      team: 'platform_insights',
      serviceAggregation: false,
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
        toolingLinks.kibana(title='Data Insights Platform', index='orbit'),
      ],
    },

    nats_jetstream: {
      team: 'platform_insights',
      serviceAggregation: false,
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
        toolingLinks.kibana(title='Data Insights Platform', index='orbit'),
      ],
    },

    gkg_webserver: {
      team: 'knowledge_graph',
      serviceAggregation: true,
      userImpacting: false,
      significantLabels: [],
      // TODO: determine feature category
      // featureCategory:
      severity: 's3',
      description: |||
        Incoming queries from rails
      |||,

      requestRate: rateMetric(
        counter='gkg_query_pipeline_queries_total',
      ),

      toolingLinks: [
        toolingLinks.kibana(title='Data Insights Platform', index='orbit'),
      ],
    },


    gkg_indexer: {
      team: 'knowledge_graph',
      serviceAggregation: true,
      userImpacting: false,
      significantLabels: [],
      // TODO: determine feature category
      // featureCategory:
      severity: 's3',
      description: |||
        GKG indexer takes data from NATS and writes to Clickhouse
      |||,

      requestRate: rateMetric(
        counter='gkg_etl_destination_rows_written_total',
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
