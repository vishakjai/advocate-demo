local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local customRateQuery = metricsCatalog.customRateQuery;
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

metricsCatalog.serviceDefinition({
  type: 'kube',
  tier: 'inf',
  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.9995,
  },
  serviceDependencies: {},
  provisioning: {
    kubernetes: false,
    vms: false,
  },
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      podSelector=null,
      hpaSelector=null,
      ingressSelector=null,
      deploymentSelector=null,
      nodeSelector={ type: 'kube' },
    ),
  },
  serviceLevelIndicators: {
    apiserver: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The Kubernetes API server validates and configures data for the api objects which
        include pods, services, and others. The API Server services REST operations
        and provides the frontend to the cluster's shared state through which all other components
        interact.

        This SLI measures all non-health-check endpoints. Long-polling endpoints are excluded from apdex scores.
      |||,

      local baseSelector = {
        job: 'apiserver',
        scope: { ne: '' },  // scope="" is used for health check endpoints
      },

      apdex: histogramApdex(
        histogram='apiserver_request_duration_seconds_bucket',
        selector=baseSelector { verb: { nre: '^(?:CONNECT|WATCHLIST|WATCH|PROXY)$' } },  // Exclude long-polling
        satisfiedThreshold=1,
        metricsFormat='migrating',
      ),

      requestRate: rateMetric(
        counter='apiserver_request_total',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='apiserver_request_total',
        selector=baseSelector { code: { re: '5..' } }
      ),

      significantLabels: ['scope', 'resource'],

      toolingLinks: [],
    },
  },
})
