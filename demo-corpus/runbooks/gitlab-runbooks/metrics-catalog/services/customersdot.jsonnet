local sliLibrary = import 'gitlab-slis/library.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local successCounterApdex = metricsCatalog.successCounterApdex;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';

local clickhouseQuerySelector = {};

local sliCommon = {
  userImpacting: true,
  serviceAggregation: false,
  team: 'fulfillment_platform',
  featureCategory: 'fulfillment_infradev',
  severity: 's2',
};

metricsCatalog.serviceDefinition({
  type: 'customersdot',
  tier: 'sv',
  tenants: ['fulfillment-platform'],

  tags: ['cloud-sql', 'memorystore-redis'],

  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.995,
  },

  serviceDependencies: {
    api: true,
  },

  provisioning: {
    vms: true,
    kubernetes: true,
  },

  regional: false,

  serviceLevelIndicators:
    sliLibrary.get('customers_dot_requests').generateServiceLevelIndicator({}, sliCommon {
      serviceAggregation: true,
      toolingLinks: [
        toolingLinks.stackdriverLogs(
          'Stackdriver Logs: CustomersDot',
          queryHash={
            'resource.type': 'gce_instance',
            'jsonPayload.controller': { exists: true },
            'jsonPayload.duration': { exists: true },
          },
          project='gitlab-subscriptions-prod',
        ),
      ],
    })
    +
    sliLibrary.get('customers_dot_sidekiq_jobs').generateServiceLevelIndicator({ type: 'customersdot' }, sliCommon {
      severity: 's3',
    })
    +
    {
      queue_durations: sliCommon {
        significantLabels: ['queue_duration_buckets'],
        severity: 's3',
        description: |||
          SLI for queue durations of CustomersDot jobs
        |||,
        requestRate: rateMetric(
          counter='gitlab_sli_customers_dot_sidekiq_jobs_queuing_total'
        ),

        errorRate: rateMetric(
          counter='gitlab_sli_customers_dot_sidekiq_jobs_queuing_error_total'
        ),

        apdex: successCounterApdex(
          successRateMetric='gitlab_sli_customers_dot_sidekiq_jobs_queuing_apdex_success_total',
          operationRateMetric='gitlab_sli_customers_dot_sidekiq_jobs_queuing_apdex_total'
        ),
      },
    }
    +
    {
      usageBillingCheckpoints: sliCommon {
        featureCategory: 'consumables_cost_management',
        trafficCessationAlertConfig: false,
        significantLabels: ['checkpoint'],
        description: |||
          SLIs to track processings (checkpoints) of Usage Billing events in CDot.
          Errors represent processing failures at a given checkpoint in the CDot pipeline.
        |||,
        requestRate: rateMetric(
          counter='gitlab_sli_customers_dot_usage_billing_events_total'
        ),

        errorRate: rateMetric(
          counter='gitlab_sli_customers_dot_usage_billing_events_error_total'
        ),
      },
    }
    +
    {
      nginx: sliCommon {
        significantLabels: [],
        description: |||
          CustomersDot NGinx metrics
        |||,

        requestRate: rateMetric(
          counter='nginx_http_requests_total',
        ),
      },
    }
    +
    {
      customersdot_redis: sliCommon {
        significantLabels: [],
        description: |||
          CustomersDot Redis metrics
        |||,

        requestRate: metricsCatalog.gaugeMetric(
          gauge='stackdriver_redis_instance_redis_googleapis_com_commands_calls',
          selector={ shard: 'customers-redis' },
          samplingInterval=60,
        ),
      },
    }
    +
    {
      customersdot_redis_cache: sliCommon {
        significantLabels: [],
        description: |||
          CustomersDot Redis-cache metrics
        |||,

        requestRate: metricsCatalog.gaugeMetric(
          gauge='stackdriver_redis_instance_redis_googleapis_com_commands_calls',
          selector={ shard: 'customers-redis-cache' },
          samplingInterval=60,
        ),
      },
    }
    +
    {
      customersdot_cloudsql: sliCommon {
        description: |||
          Represents all SQL transactions issued to the CustomersDot Postgres instance.
          Errors represent transaction rollbacks.
        |||,

        requestRate: rateMetric(
          counter='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_transaction_count',
        ),

        errorRate: rateMetric(
          counter='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_transaction_count',
          selector={ transaction_type: 'rollback' },
        ),

        significantLabels: [],
        toolingLinks: [
          toolingLinks.stackdriverLogs(
            title='Stackdriver Logs: CloudSQL',
            project='gitlab-subscriptions-prod',
            queryHash={
              'resource.type': 'cloudsql_database',
            },
          ),
        ],
      },
    }
    +
    {
      local dipWorkloadSelector = { container: { re: 'data-insights-platform-.*' } },
      customersdot_data_insights_platform: sliCommon {
        team: 'platform_insights',
        significantLabels: [],
        description: |||
          Data Insights platform is responsible for ingesting usage events generated.
        |||,
        requestRate: rateMetric(
          counter='raw_ingestion_http_requests_total',
          selector=dipWorkloadSelector,
        ),

        errorRate: rateMetric(
          counter='raw_ingestion_http_requests_total',
          selector=dipWorkloadSelector {
            code: { re: '^5.*' },
          },
        ),
        toolingLinks: [
          toolingLinks.kibana(title='Data Insights Platform', index='data_insights_platform_prdsub'),
        ],
      },

      local natsWorkloadSelector = { container: 'prom-exporter', namespace: 'nats' },
      customersdot_nats_server: sliCommon {
        team: 'platform_insights',
        significantLabels: [],
        description: |||
          NATS is responsible for buffering of events generated.
        |||,

        requestRate: rateMetric(
          counter='nats_varz_in_msgs',
          selector=natsWorkloadSelector,
        ),

        errorRate: rateMetric(
          counter='nats_varz_slow_consumers',
          selector=natsWorkloadSelector
        ),
        toolingLinks: [
          toolingLinks.kibana(title='Data Insights Platform', index='data_insights_platform_prdsub'),
        ],
      },

      customersdot_nats_jetstream: sliCommon {
        team: 'platform_insights',
        significantLabels: [],
        description: |||
          JetStream provides persistent message streaming for event processing.
        |||,

        requestRate: rateMetric(
          counter='nats_stream_total_messages',
          selector=natsWorkloadSelector,
        ),

        errorRate: rateMetric(
          counter='nats_consumer_num_redelivered',
          selector=natsWorkloadSelector,
        ),
        toolingLinks: [
          toolingLinks.kibana(title='Data Insights Platform', index='data_insights_platform_prdsub'),
        ],
      },
    } +
    {
      clickhouse_reads: sliCommon {
        description: |||
          Reads SLI for ClickHouse instances hosted via ClickHouse Cloud.
        |||,

        requestRate: rateMetric(
          counter='ClickHouseProfileEvents_SelectQuery',
          selector=clickhouseQuerySelector
        ),

        errorRate: rateMetric(
          counter='ClickHouseProfileEvents_FailedSelectQuery',
          selector=clickhouseQuerySelector,
        ),

        significantLabels: [
          'clickhouse_org',
          'clickhouse_service_name',
          'hostname',
        ],
      },
    } + {
      clickhouse_writes: sliCommon {
        trafficCessationAlertConfig: false,
        description: |||
          Writes SLI for ClickHouse instances hosted via ClickHouse Cloud.
        |||,

        requestRate: rateMetric(
          counter='ClickHouseProfileEvents_InsertQuery',
          selector=clickhouseQuerySelector
        ),

        errorRate: rateMetric(
          counter='ClickHouseProfileEvents_FailedInsertQuery',
          selector=clickhouseQuerySelector,
        ),

        significantLabels: [
          'clickhouse_org',
          'clickhouse_service_name',
          'hostname',
        ],
      },
    },

  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'All logs are available in Stackdriver',
  },
})
