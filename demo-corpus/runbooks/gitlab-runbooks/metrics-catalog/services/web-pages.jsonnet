local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local haproxyComponents = import './lib/haproxy_components.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local dependOnApi = import 'inhibit-rules/depend_on_api.libsonnet';

local baseSelector = { type: 'web-pages' };

metricsCatalog.serviceDefinition({
  type: 'web-pages',
  tier: 'sv',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],

  tags: ['golang'],

  contractualThresholds: {
    apdexRatio: 0.95,
    errorRatio: 0.05,
  },

  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.9995,
  },
  otherThresholds: {
    // Deployment thresholds are optional, and when they are specified, they are
    // measured against the same multi-burn-rates as the monitoring indicators.
    // When a service is in violation, deployments may be blocked or may be rolled
    // back.
    deployment: {
      apdexScore: 0.995,
      errorRatio: 0.9995,
    },
    mtbf: {
      apdexScore: 0.999,
      errorRatio: 0.9999,
    },
  },
  serviceDependencies: {
    'google-cloud-storage': true,
  },
  provisioning: {
    vms: true,  // pages haproxy frontend still runs on vms
    kubernetes: true,
  },

  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      ingressSelector=null,  // no ingress for web-pages
    ),
  },

  kubeResources: {
    'web-pages': {
      kind: 'Deployment',
      containers: [
        'gitlab-pages',
      ],
    },
  },
  regional: true,
  serviceLevelIndicators: {
    loadbalancer: haproxyComponents.haproxyHTTPLoadBalancer(
      userImpacting=true,
      featureCategory='pages',
      stageMappings={
        main: { backends: ['pages_http'], toolingLinks: [] },
        // TODO: cny stage for pages?
      },
      selector={ type: { re: 'pages|web-pages' } },
      dependsOn=dependOnApi.restComponents,
    ),

    loadbalancer_https: haproxyComponents.haproxyL4LoadBalancer(
      userImpacting=true,
      featureCategory='pages',
      stageMappings={
        main: { backends: ['pages_https'], toolingLinks: [] },
        // TODO: cny stage for pages?
      },
      selector={ type: { re: 'pages|web-pages' } },
      dependsOn=dependOnApi.restComponents,
    ),

    web_pages_server: {
      userImpacting: true,
      featureCategory: 'pages',
      description: |||
        Response time can be slow due to large files served by pages.
        This SLI tracks only time needed to finish writing headers.
        It includes API requests to GitLab instance, scanning ZIP archive
        for file entries, processing redirects, etc.
        We use it as stricter SLI for pages as it's independent of served file size
      |||,
      apdex: histogramApdex(
        histogram='gitlab_pages_http_time_to_write_header_seconds_bucket',
        selector=baseSelector,
        satisfiedThreshold=0.5
      ),

      requestRate: rateMetric(
        counter='gitlab_pages_http_time_to_write_header_seconds_count',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='gitlab_pages_http_requests_total',
        selector={ code: { re: '5..' } }
      ),

      significantLabels: ['fqdn'],

      toolingLinks: [
        toolingLinks.continuousProfiler(service='gitlab-pages'),
        toolingLinks.sentry(projectId=14, variables=['environment']),
        toolingLinks.kibana(title='GitLab Pages', index='pages'),
      ],
      dependsOn: dependOnApi.restComponents,
    },
  },
  capacityPlanning: {
    components: [
      {
        name: 'kube_go_memory',
        parameters: {
          ignore_outliers: [
            {
              start: '2025-12-08',
              end: '2025-12-10',
            },
          ],
        },
      },
    ],
  },
})
