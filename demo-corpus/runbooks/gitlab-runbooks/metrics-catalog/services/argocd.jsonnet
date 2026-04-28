local redisArchetype = import 'service-archetypes/redis-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local formatConfig = {
  descriptiveName: 'Redis',
};

metricsCatalog.serviceDefinition({
  type: 'argocd',
  tier: 'inf',
  tenants: ['gitlab-ops'],
  tags: ['argocd'],
  serviceIsStageless: true,
  monitoringThresholds: {
    apdexScore: 0.95,
    errorRatio: 0.95,
  },
  provisioning: {
    kubernetes: true,
    vms: false,
  },
  kubeResources: {
    'argocd-application-controller': {
      kind: 'StatefulSet',
      containers: [
        'application-controller',
      ],
    },
    'argocd-applicationset-controller': {
      kind: 'Deployment',
      containers: [
        'applicationset-controller',
      ],
    },
    'argocd-notifications-controller': {
      kind: 'Deployment',
      containers: [
        'notifications-controller',
      ],
    },
    'argocd-redis-ha-haproxy': {
      kind: 'Deployment',
      containers: [
        'haproxy',
      ],
    },
    'argocd-redis-ha-server': {
      kind: 'StatefulSet',
      containers: [
        'config-init',
        'redis',
        'sentinel',
        'split-brain-fix',
      ],
    },
    'argocd-repo-server': {
      kind: 'Deployment',
      containers: [
        'repo-server',
      ],
    },
    'argocd-server': {
      kind: 'Deployment',
      containers: [
        'server',
      ],
    },
  },
  serviceLevelIndicators: {
    istio_public_ingress: {
      userImpacting: true,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      local selector = {
        source_workload: 'istio-gateway',
        destination_workload: 'argocd-server',
      },

      apdex: histogramApdex(
        histogram='istio_request_duration_milliseconds_bucket',
        selector=selector,
        satisfiedThreshold=1000.0,
      ),

      requestRate: rateMetric(
        counter='istio_requests_total',
        selector=selector
      ),

      errorRate: rateMetric(
        counter='istio_requests_total',
        selector=selector {
          response_code: { re: '^5.*' },
        }
      ),
      emittedBy: [],  // TODO: Add type label in the source metrics https://gitlab.com/gitlab-com/gl-infra/observability/team/-/issues/2873

      significantLabels: ['destination_service', 'response_code'],
    },
    redis_primary_server: {
      apdexSkip: 'apdex for redis is measured clientside',
      severity: 's4',
      userImpacting: false,
      featureCategory: 'not_owned',
      team: 'runway',
      serviceAggregation: false,
      description: |||
        Operations on the Redis primary for %(descriptiveName)s instance.
      ||| % formatConfig,
      requestRate: metricsCatalog.rateMetric(
        counter='redis_commands_processed_total',
        selector={ type: 'argocd' },
        filterExpr='and on (instance) redis_instance_info{role="master"}'
      ),
      significantLabels: ['instance'],
      toolingLinks: [],
    },
    redis_secondary_servers: {
      apdexSkip: 'apdex for redis is measured clientside',
      severity: 's4',
      userImpacting: false,
      featureCategory: 'not_owned',
      team: 'runway',
      description: |||
        Operations on the Redis secondaries for the %(descriptiveName)s instance.
      ||| % formatConfig,
      requestRate: metricsCatalog.rateMetric(
        counter='redis_commands_processed_total',
        selector={ type: 'argocd' },
        filterExpr='and on (instance) redis_instance_info{role="slave"}'
      ),
      significantLabels: ['instance'],
      serviceAggregation: false,
    },
    redis_client: {
      severity: 's4',
      userImpacting: false,
      featureCategory: 'not_owned',
      team: 'runway',
      apdex: metricsCatalog.histogramApdex(
        histogram='argocd_redis_request_duration_seconds_bucket',
        satisfiedThreshold=2,
      ),
      requestRate: metricsCatalog.rateMetric(
        counter='argocd_redis_request_total',
        selector={ failed: 'false' }
      ),
      errorRate: metricsCatalog.rateMetric(
        counter='argocd_redis_request_total',
        selector={ failed: 'true' }
      ),
      significantLabels: [],
      toolingLinks: [
        toolingLinks.kibana('ArgoCD', index='argocd'),
      ],
    },
  },
  skippedMaturityCriteria: {
    'Service exists in the dependency graph': 'ArgoCD is a standalone infrastructure component that deploys other services.',
    'Developer guides exist in developer documentation': 'ArgoCD is an infrastructure component, developers do not interact with it',
  },
})
