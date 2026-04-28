local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local rateMetric = metricsCatalog.rateMetric;
local histogramApdex = metricsCatalog.histogramApdex;

metricsCatalog.serviceDefinition({
  // This is important for recording-rules corresponding to this
  // service to be evaluated on Thanos instead. Within services
  // owned by Monitor::Observability, we ship our metrics to an
  // internal Thanos instance which is then setup as a remote
  // query endpoint for the upstream GitLab Thanos instance, see
  // https://thanos.gitlab.net/stores -> thanos-query.opstracegcp.com:80
  dangerouslyThanosEvaluated: true,
  tenants: ['gitlab-observability'],

  type: 'tracing',
  tier: 'sv',
  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.999,
  },
  serviceDependencies: {
    api: true,
  },
  provisioning: {
    kubernetes: false,
    vms: false,
  },
  serviceLevelIndicators: {
    ingress: {
      severity: 's3',  // Don't page SREs for this SLI
      userImpacting: false,
      serviceAggregation: true,
      team: 'platform_insights',
      featureCategory: 'observability',
      description: |||
        With distributed tracing, you can troubleshoot application performance issues by
        inspecting how a request moves through different services and systems, the timing
        of each operation, and any errors or logs as they occur. Tracing is particularly
        useful in the context of microservice applications, which group multiple independent
        services collaborating to fulfil user requests.
      |||,

      local tracingCollectorSelector = {
        team: 'platform_insights',
        job: 'default/traefik',
        service: { re: 'tenant.*otel-collector-traces.*' },
      },

      requestRate: rateMetric(
        counter='traefik_service_requests_total',
        selector=tracingCollectorSelector,
      ),

      errorRate: rateMetric(
        counter='traefik_service_requests_total',
        selector=tracingCollectorSelector {
          code: { re: '^5.*' },
        },
      ),

      apdex: histogramApdex(
        histogram='traefik_service_request_duration_seconds_bucket',
        selector=tracingCollectorSelector { code: { noneOf: ['4xx', '5xx'] } },
        satisfiedThreshold=0.3,
        toleratedThreshold=5,
        metricsFormat='migrating'
      ),

      emittedBy: [],  // TODO: Add type label in the source metrics https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2873

      significantLabels: ['service'],

      toolingLinks: [
        toolingLinks.kibana(title='Observability', index='observability'),
      ],
    },
  },
})
