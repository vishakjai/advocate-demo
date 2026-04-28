local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local rateMetric = metricsCatalog.rateMetric;

// See https://istio.io/latest/docs/reference/config/metrics/ for more details about Istio metrics

metricsCatalog.serviceDefinition({
  type: 'istio',
  tier: 'inf',
  tenants: ['gitlab-gstg', 'gitlab-ops', 'gitlab-pre'],

  tags: ['golang'],

  serviceIsStageless: true,

  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },
  provisioning: {
    kubernetes: true,
    vms: false,
  },

  kubeConfig: {
    local kubeSelector = { namespace: 'istio-system' },

    labelSelectors: kubeLabelSelectors(
      deploymentSelector={ app: 'istiod' },
    ),
  },

  kubeResources: {
    istio: {
      kind: 'StatefulSet',
      containers: [
        'istiod',
      ],
    },
  },

  serviceLevelIndicators: {
    istio_pilot: {
      // Measures time in ms it takes istiod to push new config to Envoy Proxies
      userImpacting: true,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      local selector = {
        job: 'pilot',
        app: 'istiod',
      },

      apdex: histogramApdex(
        histogram='pilot_proxy_convergence_time_bucket',
        selector=selector,
        satisfiedThreshold=1000.0,
      ),

      requestRate: rateMetric(
        counter='pilot_xds_pushes',
        selector=selector
      ),
      significantLabels: ['pod'],
    },

    istio_sidecar_injection: {
      // Istio Sidecar Injectio Metrics
      userImpacting: true,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      local selector = {
        job: 'pilot',
      },

      requestRate: rateMetric(
        counter='sidecar_injection_requests_total',
        selector=selector
      ),

      errorRate: rateMetric(
        counter='sidecar_injection_failure_total',
        selector=selector
      ),
      significantLabels: ['pod'],
    },
  },
  skippedMaturityCriteria: {
    'Developer guides exist in developer documentation': 'Istio is an infrastructure component, developers do not interact with it',
    'Service exists in the dependency graph': 'This service does not interfact directly with any other services',
    'Structured logs available in Kibana': 'Istio service is not deployed in production',
  },
})
