local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';

local burnRateConfig = {
  supportedBurnRates: ['5m', '30m', '1h', '6h', '3d'],
  upscaleLongerBurnRates: true,
  upscaledBurnRates: ['3d'],
};

{
  componentSLIs: aggregationSet.AggregationSet(burnRateConfig {
    id: 'component',
    name: 'Global Component SLI Metrics',
    intermediateSource: false,
    selector: {},
    labels: ['type', 'component'],
    metricFormats: {
      apdexSuccessRate: 'gitlab_component_apdex:success:rate_%s',
      apdexWeight: 'gitlab_component_apdex:weight:score_%s',
      apdexRatio: 'gitlab_component_apdex:ratio_%s',
      opsRate: 'gitlab_component_ops:rate_%s',
      errorRate: 'gitlab_component_errors:rate_%s',
      errorRatio: 'gitlab_component_errors:ratio_%s',

      // Confidence Interval Ratios
      apdexConfidenceRatio: 'gitlab_component_apdex:confidence:ratio_%s',
      errorConfidenceRatio: 'gitlab_component_errors:confidence:ratio_%s',
    },
  }),

  /**
   * serviceSLIs consumes promSourceSLIs and aggregates
   * all the SLIs in a service up to the service level.
   * This is primarily used for visualizations, to give an
   * summary overview of the service. Not used heavily for
   * alerting.
   */
  serviceSLIs: aggregationSet.AggregationSet(burnRateConfig {
    id: 'service',
    name: 'Global Service-Aggregated Metrics',
    intermediateSource: false,
    selector: {},
    labels: ['type'],
    metricFormats: {
      apdexSuccessRate: 'gitlab_service_apdex:success:rate_%s',
      apdexWeight: 'gitlab_service_apdex:weight:score_%s',
      apdexRatio: 'gitlab_service_apdex:ratio_%s',
      opsRate: 'gitlab_service_ops:rate_%s',
      errorRate: 'gitlab_service_errors:rate_%s',
      errorRatio: 'gitlab_service_errors:ratio_%s',
    },
    // Only include components (SLIs) with service_aggregation="yes"
    aggregationFilter: 'service',
  }),

  shardComponentSLIs: aggregationSet.AggregationSet(burnRateConfig {
    id: 'component_shard',
    name: 'Global Shard-Aggregated SLI Metrics',
    intermediateSource: false,
    selector: {},
    labels: ['type', 'component', 'shard'],
    metricFormats: {
      apdexSuccessRate: 'gitlab_component_shard_apdex:success:rate_%s',
      apdexWeight: 'gitlab_component_shard_apdex:weight:score_%s',
      apdexRatio: 'gitlab_component_shard_apdex:ratio_%s',
      opsRate: 'gitlab_component_shard_ops:rate_%s',
      errorRate: 'gitlab_component_shard_errors:rate_%s',
      errorRatio: 'gitlab_component_shard_errors:ratio_%s',

      // Confidence Interval Ratios
      apdexConfidenceRatio: 'gitlab_component_shard_apdex:confidence:ratio_%s',
      errorConfidenceRatio: 'gitlab_component_shard_errors:confidence:ratio_%s',
    },
  }),
}
