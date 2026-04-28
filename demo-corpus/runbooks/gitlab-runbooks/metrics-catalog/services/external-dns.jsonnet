local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'external-dns',
  tier: 'sv',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-ops', 'gitlab-pre'],

  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },

  provisioning: {
    kubernetes: true,
    vms: false,
  },

  serviceDependencies: {
    kube: true,
  },

  kubeResources: {
    'external-dns': {
      kind: 'Deployment',
      containers: [
        'external-dns',
      ],
    },
  },

  serviceLevelIndicators: {},
  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'Logs from external-dns are not ingested to ElasticSearch due to volume. Besides, the logs are also available in Stackdriver',
    'Developer guides exist in developer documentation': 'external-dns is an infrastructure component, developers do not interact with it',
  },
})
