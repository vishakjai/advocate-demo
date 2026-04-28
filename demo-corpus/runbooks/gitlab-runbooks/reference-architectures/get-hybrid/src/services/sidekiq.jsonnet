local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local combined = metricsCatalog.combined;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local successCounterApdex = metricsCatalog.successCounterApdex;
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local serviceLevelIndicatorDefinition = import 'servicemetrics/service_level_indicator_definition.libsonnet';
local gitlabMetricsConfig = (import 'gitlab-metrics-config.libsonnet');

local significantLabels = ['feature_category', 'worker'];

metricsCatalog.serviceDefinition({
  type: 'sidekiq',
  tier: 'sv',
  tags: ['rails', 'kube_container_rss'],
  monitoring: {
    shard: {
      enabled: true,
      overrides: gitlabMetricsConfig.options.monitoring.sidekiq,
    },
  },
  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.995,
  },
  otherThresholds: {},
  serviceDependencies: {},
  provisioning: {
    kubernetes: true,
    vms: false,
  },
  // Use recordingRuleMetrics to specify a set of metrics with known high
  // cardinality. The metrics catalog will generate recording rules with
  // the appropriate aggregations based on this set.
  // Use sparingly, and don't overuse.
  recordingRuleMetrics: [
    'sidekiq_jobs_completion_seconds_bucket',
    'sidekiq_jobs_queue_duration_seconds_bucket',
    'sidekiq_jobs_failed_total',
  ],
  kubeConfig: {
    local kubeSelector = { app: 'sidekiq' },
    labelSelectors: kubeLabelSelectors(
      podSelector=kubeSelector,
      ingressSelector=null,
      // Using a pattern to match all sidekiq HPAs
      hpaSelector={ horizontalpodautoscaler: { re: 'gitlab-sidekiq-.*' } },
      nodeSelector={ workload: 'sidekiq' },
      deploymentSelector=kubeSelector
    ),
  },

  useConfidenceLevelForSLIAlerts: '98%',

  serviceLevelIndicators: {
    sidekiq_execution: {
      userImpacting: true,
      // The per shard SLIs above already make up the service aggrergation
      serviceAggregation: true,
      severity: 's2',
      featureCategory: serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics,
      description: |||
        Sidekiq job completion timings.

         This is the time it takes for jobs to execute once they've been picked up by a worker.
         A dip in this apdex indicates that jobs are not completing within the expected time frame.  This can be caused by many possibilities, including:
         1. Resource contention in the workers (e.g. thread contention for CPU time, due to high concurrency),
         2. Resource contention in other resources (e.g. database CPU saturation),
         3. Poorly performing worker code or queries

         Satisfied queue latency thresholds are defined in the application by urgency.
         See <https://docs.gitlab.com/development/sidekiq/worker_attributes/#job-urgency>

         1. 10s for high urgency jobs.
         2. 5m for low urgency jobs.
         3. 5m for throttled jobs.
      |||,
      requestRate: rateMetric('gitlab_sli_sidekiq_execution_total'),
      errorRate: rateMetric('gitlab_sli_sidekiq_execution_error_total'),
      apdex: successCounterApdex(
        successRateMetric='gitlab_sli_sidekiq_execution_apdex_success_total',
        operationRateMetric='gitlab_sli_sidekiq_execution_apdex_total'
      ),
      significantLabels: significantLabels,
      toolingLinks: [],
    },

    sidekiq_queueing: {
      userImpacting: true,
      serviceAggregation: false,
      severity: 's2',
      featureCategory: serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics,
      description: |||
        Sidekiq queue latency per shard.

        This is the time it takes for jobs to be picked up in the queue.
        A dip in this Apdex indicates that the queues are saturated and cannot process the backlog of jobs fast enough.

        Satisfied queue latency thresholds are defined in the application by urgency.
        See <https://docs.gitlab.com/development/sidekiq/worker_attributes/#job-urgency>

        1. 10s for high urgency jobs.
        2. 1m for low urgency jobs.
        3. throttled jobs do not have an expected duration.
      |||,

      requestRate: rateMetric('gitlab_sli_sidekiq_queueing_apdex_total'),
      apdex: successCounterApdex(
        successRateMetric='gitlab_sli_sidekiq_queueing_apdex_success_total',
        operationRateMetric='gitlab_sli_sidekiq_queueing_apdex_total'
      ),
      significantLabels: significantLabels,
      toolingLinks: [],
    },
  },
})
