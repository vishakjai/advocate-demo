local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'consul',
  tier: 'sv',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-ops', 'gitlab-pre'],

  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },
  serviceDependencies: {
  },
  provisioning: {
    vms: true,
    kubernetes: true,
  },
  regional: true,
  kubeConfig: {
    local kubeSelector = { namespace: 'consul' },

    labelSelectors: kubeLabelSelectors(
      hpaSelector=null,  // no hpas for consul
      ingressSelector=null,  // no ingress for consul
      deploymentSelector=null,  // no deployments for consul
      nodeSelector=null  // running on generic nodepools
    ),
  },
  kubeResources: {
    consul: {
      kind: 'StatefulSet',
      containers: [
        'consul',
      ],
    },
  },
  serviceLevelIndicators: {
    consul: {
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        Increments whenever a Consul agent in client mode makes an RPC request to a Consul server
      |||,

      local ConsulSelector = {
        job: 'consul-gl-consul-ui',
      },
      requestRate: rateMetric(
        counter='consul_client_rpc',
        selector=ConsulSelector,
      ),

      errorRate: rateMetric(
        counter='consul_client_rpc_failed',
        selector=ConsulSelector,
      ),
      emittedBy: [],  // TODO: Add type label in the source metrics https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2873
      toolingLinks: [
        toolingLinks.kibana(title='Consul', index='consul', includeMatchersForPrometheusSelector=false),
      ],
      significantLabels: ['pod'],
    },
  },
  skippedMaturityCriteria: {
    'Developer guides exist in developer documentation': 'Consul is an infrastructure component, developers do not interact with it',
  },
})
