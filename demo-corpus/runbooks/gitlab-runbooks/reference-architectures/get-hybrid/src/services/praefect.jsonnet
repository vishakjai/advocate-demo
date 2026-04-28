local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local gaugeMetric = metricsCatalog.gaugeMetric;
local histogramApdex = metricsCatalog.histogramApdex;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local gitalyHelper = import 'service-archetypes/helpers/gitaly.libsonnet';
local gitlabMetricsConfig = (import 'gitlab-metrics-config.libsonnet');
local apdexOptions = gitlabMetricsConfig.options.apdexThresholds.praefect;

metricsCatalog.serviceDefinition({
  type: 'praefect',
  tier: 'stor',

  tags: ['golang'],

  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.9995,  // 99.95% of Praefect requests should succeed, over multiple window periods
  },

  // A 98% confidence interval will be used for all SLIs on this service
  useConfidenceLevelForSLIAlerts: '98%',

  serviceLevelIndicators: {
    proxy: {
      userImpacting: true,
      description: |||
        All Gitaly operations pass through the Praefect proxy on the way to a Gitaly instance. This SLI monitors
        those operations in aggregate.
      |||,

      local baseSelector = { job: 'praefect' },
      apdex: gitalyHelper.grpcServiceApdex(
        baseSelector,
        satisfiedThreshold=apdexOptions.satisfied,
        toleratedThreshold=apdexOptions.tolerated,
      ),

      requestRate: rateMetric(
        counter='grpc_server_handled_total',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='grpc_server_handled_total',
        selector=baseSelector {
          grpc_code: { nre: '^(OK|NotFound|Unauthenticated|AlreadyExists|FailedPrecondition|Canceled)$' },
        }
      ),

      significantLabels: ['node'],

      toolingLinks: [],
    },

    // The replicator_queue handles replication jobs from Praefect to secondaries
    // the apdex measures the percentage of jobs that dequeue within the SLO
    // See:
    // * https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/11027
    // * https://gitlab.com/gitlab-org/gitaly/-/issues/2915
    replicator_queue: {
      userImpacting: false,
      description: |||
        Praefect replication operations. Latency represents the queuing delay before replication is carried out.
      |||,

      local baseSelector = {},
      apdex: histogramApdex(
        histogram='gitaly_praefect_replication_delay_bucket',
        selector=baseSelector,
        satisfiedThreshold=300,
        metricsFormat='migrating',
      ),

      requestRate: rateMetric(
        counter='gitaly_praefect_replication_delay_bucket',
        selector=baseSelector { le: '+Inf' }
      ),

      significantLabels: ['node', 'type'],
    },
  },
})
