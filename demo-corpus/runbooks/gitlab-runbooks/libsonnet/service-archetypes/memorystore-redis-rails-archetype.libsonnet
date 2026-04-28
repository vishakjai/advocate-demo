local redisArchetype = import 'service-archetypes/redis-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local findServicesWithTag = (import 'servicemetrics/metrics-catalog.libsonnet').findServicesWithTag;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

function(
  type,
  railsStorageSelector,
  descriptiveName,
  featureCategory='not_owned',
  redisCluster=false,
)
  redisArchetype(type, descriptiveName, featureCategory, redisCluster)
  {
    provisioning: {
      // This is a GCP managed service - Memorystore for Redis
      vms: false,
      kubernetes: false,
    },
    tags: [
      'memorystore-redis',
    ],
    serviceLevelIndicators: {
      rails_redis_client: {
        userImpacting: true,
        featureCategory: featureCategory,
        description: |||
          Aggregation of all %(descriptiveName)s operations issued from the Rails codebase
          through `Gitlab::Redis::Wrapper` subclasses.
        ||| % { descriptiveName: descriptiveName },
        significantLabels: ['type'],

        apdex: histogramApdex(
          histogram='gitlab_redis_client_requests_duration_seconds_bucket',
          selector=railsStorageSelector,
          satisfiedThreshold=0.5,
          toleratedThreshold=0.75,
        ),

        requestRate: rateMetric(
          counter='gitlab_redis_client_requests_total',
          selector=railsStorageSelector,
        ),

        errorRate: rateMetric(
          counter='gitlab_redis_client_exceptions_total',
          selector=railsStorageSelector,
        ),

        emittedBy: findServicesWithTag(tag='rails'),
      },
      primary_server: {
        apdexSkip: 'apdex for redis is measured clientside',
        userImpacting: true,
        featureCategory: featureCategory,
        serviceAggregation: false,
        shardLevelMonitoring: false,
        description: |||
          Operations on the Redis primary for GCP managed Memorystore for Redis instance.
        |||,
        requestRate: metricsCatalog.gaugeMetric(
          gauge='stackdriver_redis_instance_redis_googleapis_com_commands_calls',
          selector={ type: type },
          samplingInterval=60,
        ),
        emittedBy: [type],

        significantLabels: ['instance'],

        toolingLinks: [
          toolingLinks.stackdriverLogs(
            'Memorystore for Redis Audit logs in Cloud Logging',
            queryHash={
              'protoPayload.serviceName': 'redis.googleapis.com',
            },
            timeRange='PT6H',
          ),
          toolingLinks.stackdriverLogs(
            'Memorystore for Redis Activity Logs in Cloud Logging',
            queryHash={
              'resource.type': 'redis_instance',
              'resource.labels.instance_id': type,
            },
            timeRange='PT6H',
          ),
        ],
      },
    },
    skippedMaturityCriteria+: {
      'Structured logs available in Kibana': 'GCP-managed Memorystore Redis does not have kibana logs',
    },
  }
