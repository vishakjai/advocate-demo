local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';
local registryCustomRouteSLIs = import './lib/registry-custom-route-slis.libsonnet';
local registryArchetype = import 'service-archetypes/registry-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local haproxyComponents = import './lib/haproxy_components.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;

local customRouteSLIs = registryCustomRouteSLIs.customApdexRouteConfig;

local defaultRegistrySLIProperties = {
  userImpacting: true,
  featureCategory: 'container_registry',
};

local defaultRegistrySLIToolingLinks = [
  toolingLinks.gkeDeployment('gitlab-registry', type='registry', containerName='registry'),
  toolingLinks.kibana(title='Registry', index='registry', type='registry', slowRequestSeconds=10),
  toolingLinks.continuousProfiler(service='gitlab-registry'),
];

local registryBaseSelector = {
  type: 'registry',
};

metricsCatalog.serviceDefinition(
  registryArchetype(
    contractualThresholds={
      apdexRatio: 0.9,
      errorRatio: 0.005,
    },
    customRouteSLIs=customRouteSLIs,
    defaultRegistrySLIProperties=defaultRegistrySLIProperties,
    defaultRegistrySLIToolingLinks=defaultRegistrySLIToolingLinks,
    kubeConfig={
      labelSelectors: kubeLabelSelectors(
        ingressSelector=null,  // no ingress for registry
      ),
    },
    otherThresholds={
      // Deployment thresholds are optional, and when they are specified, they are
      // measured against the same multi-burn-rates as the monitoring indicators.
      // When a service is in violation, deployments may be blocked or may be rolled
      // back.
      deployment: {
        apdexScore: 0.9929,
        errorRatio: 0.9700,
      },

      mtbf: {
        apdexScore: 0.9995,
        errorRatio: 0.99995,
      },
    },
    provisioning={
      kubernetes: true,
      vms: true,  // registry haproxy frontend still runs on vms
    },
    // Git service is spread across multiple regions, monitor it as such
    regional=true,
    registryBaseSelector=registryBaseSelector,
    serviceDependencies={
      api: true,
      'redis-cluster-registry': true,
    },
    additionalServiceLevelIndicators={
      registry_cdn: googleLoadBalancerComponents.googleLoadBalancer(
        userImpacting=true,
        loadBalancerName='gprd-registry-cdn',
        projectId='gitlab-production',
        featureCategory='container_registry',
      ),

      loadbalancer: haproxyComponents.haproxyHTTPLoadBalancer(
        userImpacting=true,
        featureCategory='container_registry',
        stageMappings={
          main: { backends: ['registry'], toolingLinks: [] },
          cny: { backends: ['canary_registry'], toolingLinks: [] },
        },
        selector=registryBaseSelector,
        regional=false
      ),

      database: {
        userImpacting: true,
        featureCategory: 'container_registry',
        description: |||
          Aggregation of all container registry database operations.
        |||,

        apdex: histogramApdex(
          histogram='registry_database_query_duration_seconds_bucket',
          selector=registryBaseSelector,
          satisfiedThreshold=0.5,
          toleratedThreshold=1,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='registry_database_queries_total',
          selector=registryBaseSelector
        ),

        significantLabels: ['name'],
      },

      garbagecollector: {
        severity: 's3',
        userImpacting: false,
        serviceAggregation: false,
        featureCategory: 'container_registry',
        description: |||
          Aggregation of all container registry online garbage collection operations.
        |||,

        apdex: histogramApdex(
          histogram='registry_gc_run_duration_seconds_bucket',
          selector={ type: 'registry' },
          satisfiedThreshold=0.5,
          toleratedThreshold=1,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='registry_gc_runs_total',
          selector=registryBaseSelector
        ),

        errorRate: rateMetric(
          counter='registry_gc_runs_total',
          selector=registryBaseSelector {
            'error': 'true',
          }
        ),

        significantLabels: ['worker'],
        toolingLinks: [
          toolingLinks.kibana(
            title='Garbage Collector',
            index='registry_garbagecollection',
            type='registry',
            matches={ 'json.component': ['registry.gc.Agent', 'registry.gc.worker.ManifestWorker', 'registry.gc.worker.BlobWorker'] }
          ),
        ],
      },

      redis: {
        userImpacting: true,
        featureCategory: 'container_registry',
        description: |||
          Aggregation of all container registry Redis operations.
        |||,

        apdex: histogramApdex(
          histogram='registry_redis_single_commands_bucket',
          selector=registryBaseSelector,
          satisfiedThreshold=0.25,
          toleratedThreshold=0.5
        ),

        requestRate: rateMetric(
          counter='registry_redis_single_commands_count',
          selector=registryBaseSelector
        ),

        errorRate: rateMetric(
          counter='registry_redis_single_errors_count',
          selector=registryBaseSelector
        ),

        significantLabels: ['instance', 'command'],
      },

      notifications: {
        userImpacting: false,
        severity: 's3',
        serviceAggregation: false,
        featureCategory: 'container_registry',
        description: |||
          Aggregation of all container registry operations related to sending notifications.
        |||,

        apdex: histogramApdex(
          histogram='registry_notifications_total_latency_seconds_bucket',
          selector=registryBaseSelector,
          satisfiedThreshold=5,
          toleratedThreshold=10,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='registry_notifications_delivery_total',
          selector=registryBaseSelector
        ),

        errorRate: rateMetric(
          counter='registry_notifications_delivery_total',
          selector=registryBaseSelector { delivery_type: 'lost' }
        ),

        significantLabels: ['endpoint'],
      },
    },
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
  }
  +
  {
    capacityPlanning: {
      components: [
        {
          name: 'node_schedstat_waiting',
          parameters: {
            ignore_outliers: [
              {
                start: '2022-10-30',  // https://gitlab.com/groups/gitlab-org/-/epics/5523
                end: '2023-01-30',
              },
            ],
          },
        },
      ],
    },
  }
)
