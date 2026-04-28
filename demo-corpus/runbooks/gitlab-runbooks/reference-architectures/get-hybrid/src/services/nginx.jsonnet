local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local successCounterApdex = metricsCatalog.successCounterApdex;
local gitlabMetricsConfig = (import 'gitlab-metrics-config.libsonnet');
local monitoringThresholds = gitlabMetricsConfig.options.monitoring.nginx.monitoringThresholds;
local alertWindows = gitlabMetricsConfig.options.monitoring.nginx.alertWindows;

metricsCatalog.serviceDefinition({
  type: 'nginx',
  tier: 'sv',

  tags: ['nginx', 'kube_container_rss'],

  monitoringThresholds: monitoringThresholds,
  alertWindows: alertWindows,

  otherThresholds: {},
  serviceDependencies: {},
  provisioning: {
    vms: false,
    kubernetes: true,
  },
  regional: false,
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      podSelector={ app: 'nginx-ingress' },
      nodeSelector={ eks_amazonaws_com_nodegroup: 'gitlab_webservice_pool' },
      ingressSelector=null,
    ),
  },
  kubeResources: {
    'gitlab-nginx': {
      kind: 'DaemonSet',
      containers: [
        'controller',
      ],
    },
  },

  // A 98% confidence interval will be used for all SLIs on this service
  useConfidenceLevelForSLIAlerts: '98%',

  serviceLevelIndicators:
    {
      nginx_ingress: {
        userImpacting: true,
        trafficCessationAlertConfig: true,
        description: |||
          All requests passing through the Nginx ingress controller. Errors are 5xx status codes.
        |||,

        local baseSelector = {},

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

        significantLabels: ['type', 'status'],

        emittedBy: [],

        toolingLinks: [
          toolingLinks.opensearchDashboards(title='Nginx', index='nginx', containerName='controller'),
        ],
      },
    },
})
