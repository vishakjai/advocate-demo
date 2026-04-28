local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'atlantis',
  tier: 'inf',
  tenants: ['gitlab-ops'],

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

  kubeResources: {
    'atlantis-ops': {
      kind: 'StatefulSet',
      containers: [
        'atlantis',
      ],
    },
    'atlantis-ops-config-mgmt': {
      kind: 'StatefulSet',
      containers: [
        'atlantis',
      ],
    },
  },

  serviceLevelIndicators: {
    // Google Load Balancer for https://atlantis-ops.ops.gke.gitlab.net/
    atlantis_google_lb: googleLoadBalancerComponents.googleLoadBalancer(
      userImpacting=false,
      // LB automatically created by the k8s ingress
      loadBalancerName='k8s2-um-4zodnh0s-atlantis-atlantis-ops-003jd693',
      projectId='gitlab-ops',
      trafficCessationAlertConfig=false
    ),
  },
  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'Atlantis is a work in progress, see https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/24613',
    'Service exists in the dependency graph': 'Atlantis is a work in progress, see https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/24613',
    'Developer guides exist in developer documentation': 'Atlantis is an infrastructure component, developers do not interact with it',
  },
})
