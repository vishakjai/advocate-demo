local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

metricsCatalog.serviceDefinition({
  type: 'nginx',
  tier: 'sv',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
  monitoringThresholds: {
    // apdexScore: 0.995,
    // errorRatio: 0.999,
  },
  serviceDependencies: {
    api: false,
    web: false,
  },
  provisioning: {
    vms: false,
    kubernetes: true,
  },
  regional: true,
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      hpaSelector={ type: 'nginx' },

      // NGINX *is* the ingress
      ingressSelector=null,
    ),
  },
  kubeResources: {
    'gitlab-nginx': {
      kind: 'Deployment',
      containers: [
        'controller',
      ],
    },
  },
  serviceLevelIndicators: {
    nginx_ingress: {
      userImpacting: true,
      trafficCessationAlertConfig: false,
      featureCategory: 'not_owned',
      team: 'sre_reliability',
      description: |||
        nginx ingress
      |||,

      local baseSelector = { app: 'nginx-ingress' },

      requestRate: rateMetric(
        counter='nginx_ingress_controller_requests:labeled',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='nginx_ingress_controller_requests:labeled',
        selector=baseSelector {
          status: { re: '^5.*' },
        }
      ),

      emittedBy: ['api', 'web'],

      significantLabels: ['path', 'status'],

      toolingLinks: [
        toolingLinks.stackdriverLogs(
          'NGINX stderr',
          queryHash={
            'resource.type': 'k8s_container',
            'labels."k8s-pod/app"': 'nginx-ingress',
            logName: { one_of: ['projects/gitlab-production/logs/stderr', 'projects/gitlab-staging-1/logs/stderr'] },
          },
        ),
      ],
    },
  },
  skippedMaturityCriteria: {
    'Developer guides exist in developer documentation': 'Application logic does not interact with nginx',
    'Structured logs available in Kibana': 'Logs from nginx are not ingested to ElasticSearch due to volume. Usually, workhorse logs will cover the same ground. Besides, the logs are also available in Stackdriver',
  },
})
