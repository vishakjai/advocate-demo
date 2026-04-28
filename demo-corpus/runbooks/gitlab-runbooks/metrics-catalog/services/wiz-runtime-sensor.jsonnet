local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'wiz-runtime-sensor',
  tier: 'inf',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-ops', 'gitlab-pre'],
  tags: ['wiz-sensor', 'kube_container_rss'],

  serviceIsStageless: true,

  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },

  provisioning: {
    kubernetes: true,
    vms: true,
  },

  kubeResources: {
    'wiz-sensor': {
      kind: 'daemonset',
      containers: [
        'wiz-sensor',
      ],
    },
  },

  serviceLevelIndicators: {},

  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'Wiz Runtime Sensor is deployed on all k8s environments and the logs are forwarded to CloudLogging and Devo Ref issue https://gitlab.com/gitlab-com/gl-security/product-security/infrastructure-security/bau/-/issues/8400 to check sample logs',
    'Service exists in the dependency graph': 'Wiz Runtime Sensor does not interact directly with any declared services in our system',
  },
})
