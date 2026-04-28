local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local gitalyHelper = import 'service-archetypes/helpers/gitaly.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local gitlabMetricsConfig = (import 'gitlab-metrics-config.libsonnet');
local apdexOptions = gitlabMetricsConfig.options.apdexThresholds.gitaly;
local monitoringThresholds = gitlabMetricsConfig.options.monitoring.gitaly.monitoringThresholds;

metricsCatalog.serviceDefinition({
  type: 'gitaly',
  tier: 'stor',

  tags: ['golang'],

  nodeLevelMonitoring: false,

  monitoringThresholds: monitoringThresholds,

  // A 98% confidence interval will be used for all SLIs on this service
  useConfidenceLevelForSLIAlerts: '98%',

  serviceLevelIndicators: {
    goserver: {
      userImpacting: true,
      description: |||
        This SLI monitors all Gitaly GRPC requests in aggregate, excluding the OperationService.
        GRPC failures which are considered to be the "server's fault" are counted as errors.
        The apdex score is based on a subset of GRPC methods which are expected to be fast.
      |||,

      local baseSelector = {
        job: 'gitaly',
        grpc_service: { ne: 'gitaly.OperationService' },
      },

      local baseSelectorApdex = baseSelector {
        grpc_method: { noneOf: gitalyHelper.gitalyApdexIgnoredMethods },
      },

      apdex: gitalyHelper.grpcServiceApdex(
        baseSelectorApdex,
        satisfiedThreshold=apdexOptions.satisfied,
        toleratedThreshold=apdexOptions.tolerated,
      ),

      requestRate: rateMetric(
        counter='gitaly_service_client_requests_total',
        selector=baseSelector
      ),

      errorRate: gitalyHelper.gitalyGRPCErrorRate(baseSelector),

      significantLabels: ['node'],

      toolingLinks: [
        toolingLinks.opensearchDashboards(title='Gitaly', index='gitaly', matches={ fluentd_tag: 'gitaly.app' }, slowRequestSeconds=1),
      ],
    },
  },
})
