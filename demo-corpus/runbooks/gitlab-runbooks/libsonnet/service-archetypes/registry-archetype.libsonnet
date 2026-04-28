local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local combined = metricsCatalog.combined;
local gitalyHelper = import 'service-archetypes/helpers/gitaly.libsonnet';
local registryHelper = import 'service-archetypes/helpers/registry.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

function(
  type='registry',
  extraTags=[],
  additionalServiceLevelIndicators={},
  contractualThresholds={},
  customRouteSLIs=[],
  defaultRegistrySLIProperties={
    userImpacting: true,
  },
  defaultRegistrySLIToolingLinks=[],
  defaultRegistryComponent='registry_server',
  kubeConfig,
  kubeResourceName='registry',
  otherThresholds={},
  provisioning={
    kubernetes: true,
    vms: false,
  },
  regional=false,
  registryBaseSelector={},
  serviceDependencies={},
) {
  type: type,
  tier: 'sv',
  tags: ['golang'] + extraTags,
  contractualThresholds: contractualThresholds,
  monitoringThresholds: {
    apdexScore: 0.997,
    errorRatio: 0.9999,
  },
  otherThresholds: otherThresholds,
  regional: regional,
  kubeConfig: kubeConfig,
  kubeResources: {
    [kubeResourceName]: {
      kind: 'Deployment',
      containers: [
        'registry',
      ],
    },
  },
  nodeLevelMonitoring: false,
  provisioning: provisioning,
  serviceDependencies: serviceDependencies,
  serviceLevelIndicators: additionalServiceLevelIndicators {
    [defaultRegistryComponent]: defaultRegistrySLIProperties {
      userImpacting: true,
      description: |||
        Aggregation of all registry HTTP requests.
      |||,

      apdex: registryHelper.mainApdex(registryBaseSelector, customRouteSLIs),

      requestRate: rateMetric(
        counter='registry_http_requests_total',
        selector=registryBaseSelector
      ),

      errorRate: rateMetric(
        counter='registry_http_requests_total',
        selector=registryBaseSelector {
          code: { re: '5..' },
        }
      ),

      significantLabels: ['route', 'method'],

      toolingLinks: defaultRegistrySLIToolingLinks,
    },
  } + registryHelper.apdexPerRoute(registryBaseSelector, defaultRegistrySLIProperties, customRouteSLIs),
}
