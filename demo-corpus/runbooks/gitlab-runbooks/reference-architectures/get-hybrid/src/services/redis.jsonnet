local redisHelpers = import '../../../metrics-catalog/services/lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local findServicesWithTag = (import 'servicemetrics/metrics-catalog.libsonnet').findServicesWithTag;

// In Dedicated, we don't have as many Redis instances, thus let's select
// all storage types to be monitored inside of one view - thus no selector
local railsStoreSelector = {};

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis',
    railsStorageSelector=railsStoreSelector,
    descriptiveName='Redis',
  )
  {
    // Provisioned using some sort of Cloud Service
    provisioning+: {
      vms: false,
      kubernetes: false,
    },
    monitoringThresholds+: {
      apdexScore: 0.9995,
    },

    // A 98% confidence interval will be used for all SLIs on this service
    useConfidenceLevelForSLIAlerts: '98%',

    serviceLevelIndicators+: {
      redis: {
        userImpacting: true,
        featureCategory: 'not_owned',

        apdex: histogramApdex(
          histogram='gitlab_cache_operation_duration_seconds_bucket',
          selector=railsStoreSelector,
          satisfiedThreshold=0.1,
          toleratedThreshold=0.25
        ),

        requestRate: rateMetric(
          counter='gitlab_cache_operation_duration_seconds_count',
          selector=railsStoreSelector,
        ),

        emittedBy: findServicesWithTag(tag='rails'),

        significantLabels: [],
      },

      // In cloud deployed instances, we have no secondaries for which we have exporters attached
      secondary_servers:: null,
    },
  }
)
