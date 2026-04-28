local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local sidekiqHelpers = import './lib/sidekiq-helpers.libsonnet';
local combined = metricsCatalog.combined;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local sliLibrary = import 'gitlab-slis/library.libsonnet';
local findServicesWithTag = (import 'servicemetrics/metrics-catalog.libsonnet').findServicesWithTag;
local selectors = import 'promql/selectors.libsonnet';

// Some workers have known performance issues that surpass our thresholds.
// Each worker should have a link to an issue to fix the performance issues.
local ignoredWorkers = { worker: {
  ne: [
    'Security::StoreSecurityReportsByProjectWorker',  // https://gitlab.com/gitlab-com/gl-infra/production-engineering/-/issues/26967#note_2577951055
    'Search::Zoekt::UpdateIndexUsedStorageBytesEventWorker',  // https://gitlab.com/gitlab-org/gitlab/-/work_items/592620
  ],
} };

local baseSelector = { type: 'sidekiq' } + ignoredWorkers;


metricsCatalog.serviceDefinition({
  type: 'sidekiq',
  tier: 'sv',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
  tags: ['rails', 'kube_container_rss'],
  shards: sidekiqHelpers.shards.listByName(),

  // overrides monitoringThresholds for specific shards and SLIs
  monitoring: {
    shard: {
      enabled: true,
      overrides: {
        sidekiq_execution: {
          'urgent-authorized-projects': {
            apdexScore: 0.95,
          },
          'urgent-other': {
            apdexScore: 0.985,
          },
          'urgent-cpu-bound': {
            apdexScore: 0.99,
          },
        },
        sidekiq_queueing: {
          'urgent-authorized-projects': {
            apdexScore: 0.94,
          },
          catchall: {
            apdexScore: 0.99,
          },
          'catchall-b': {
            apdexScore: 0.99,
          },
          'urgent-cpu-bound': {
            apdexScore: 0.99,
          },
          'import-shared-storage': {
            apdexScore: 0.95,
          },
          elasticsearch: {
            apdexScore: 0.94,
          },
        },
      },
    },
  },

  contractualThresholds: {
    apdexRatio: 0.9,
    errorRatio: 0.1,
  },
  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.995,
  },
  otherThresholds: {
    // Deployment thresholds are optional, and when they are specified, they are
    // measured against the same multi-burn-rates as the monitoring indicators.
    // When a service is in violation, deployments may be blocked or may be rolled
    // back.
    deployment: {
      apdexScore: 0.995,
      errorRatio: 0.995,
    },
  },
  serviceDependencies: {
    gitaly: true,
    'memorystore-redis-tracechunks': true,
    'redis-sidekiq': true,
    'redis-cluster-queues-meta': true,
    'redis-cluster-cache': true,
    'redis-cluster-database-lb': true,
    'redis-cluster-repo-cache': true,
    'redis-cluster-sessions': true,
    redis: true,
    patroni: true,
    pgbouncer: true,
    'ext-pvs': true,
    search: true,
    consul: true,
    'google-cloud-storage': true,
    zoekt: true,
  },
  provisioning: {
    kubernetes: true,
    vms: false,
  },
  // Use recordingRuleMetrics to specify a set of metrics with known high
  // cardinality. The metrics catalog will generate recording rules with
  // the appropriate aggregations based on this set.
  // Use sparingly, and don't overuse.
  recordingRuleMetrics: [
    'sidekiq_enqueued_jobs_total',
  ] + (
    sliLibrary.get('sidekiq_execution').recordingRuleMetrics
    + sliLibrary.get('sidekiq_queueing').recordingRuleMetrics
  ),
  kubeConfig: {
    labelSelectors: kubeLabelSelectors(
      ingressSelector=null,  // no ingress for sidekiq
      // Sidekiq nodes don't present a stage label at present, so\
      // we hardcode to main stage
      nodeStaticLabels={ stage: 'main' },
    ),
  },
  kubeResources: std.foldl(
    function(memo, shard)
      memo {
        // Deployment tags follow the convention sidekiq-catchall etc
        ['sidekiq-' + shard.name]: {
          kind: 'Deployment',
          containers: [
            'sidekiq',
          ],
        },
      },
    sidekiqHelpers.shards.listAll(),
    {},
  ),
  serviceLevelIndicators: {
    enqueued_jobs: {
      serviceAggregation: false,  // Don't add this to the request rate of the service
      shardLevelMonitoring: false,
      userImpacting: true,
      description: |||
        The number of jobs enqueued by Sidekiq clients (api, web, sidekiq, etc).
      |||,

      requestRate: rateMetric(
        counter='sidekiq_enqueued_jobs_total',
      ),

      emittedBy: findServicesWithTag(tag='rails'),
      significantLabels: ['queue', 'feature_category', 'urgency', 'worker'],
    },
  } + sliLibrary.get('sidekiq_execution').generateServiceLevelIndicator(baseSelector { external_dependencies: { ne: 'yes' } }, {
    // TODO: For now, only sidekiq execution is considered towards service aggregation
    // which means queueing is not part of the service aggregation & SLA.
    // Future plan is to be able to specify either apdex, errors, or ops to be included in service aggregaiton.
    // See https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2423.
    serviceAggregation: true,
    severity: 's2',
    toolingLinks: [
      // Improve sentry link once https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/532 arrives
      toolingLinks.sentry(projectId=3, type='sidekiq', variables=['environment', 'stage']),
      toolingLinks.kibana(title='Sidekiq execution', index='sidekiq_execution', type='sidekiq'),
    ],
    trafficCessationAlertConfig: sidekiqHelpers.shardTrafficCessationAlertConfig,
  }) + sliLibrary.get('sidekiq_queueing').generateServiceLevelIndicator(baseSelector, {
    serviceAggregation: false,  // Don't add this to the request rate of the service
    severity: 's2',
    toolingLinks: [
      toolingLinks.kibana(title='Sidekiq queueing', index='sidekiq_queueing', type='sidekiq'),
    ],
    featureCategory: 'not_owned',
    trafficCessationAlertConfig: sidekiqHelpers.shardTrafficCessationAlertConfig,
    monitoringThresholds+: {
      apdexScore: 0.999,
    },
  }) + sliLibrary.get('sidekiq_execution_with_external_dependency').generateServiceLevelIndicator(baseSelector { external_dependencies: { eq: 'yes' } }, {
    serviceAggregation: false,  // Don't add this to the request rate of the service
    shardLevelMonitoring: false,
    severity: 's3',
    monitoringThresholds+: {
      errorRatio: 0.9,
    },
    trafficCessationAlertConfig: sidekiqHelpers.shardTrafficCessationAlertConfig,
  }) + sliLibrary.get('llm_completion').generateServiceLevelIndicator({}, {
    serviceAggregation: false,
    shardLevelMonitoring: false,
    severity: 's4',
    toolingLinks: [
      toolingLinks.kibana(
        title='Sidekiq CompletionWorker',
        index='sidekiq',
        matches={ 'json.class.keyword': 'Llm::CompletionWorker' }
      ),
    ],
    trafficCessationAlertConfig: sidekiqHelpers.shardTrafficCessationAlertConfig,
    emittedBy: ['ops-gitlab-net', 'sidekiq'],
  }) + sliLibrary.get('security_scan').generateServiceLevelIndicator({}, {
    serviceAggregation: false,
    severity: 's4',
    emittedBy: ['sidekiq'],
  }) + sliLibrary.get('llm_chat_first_token').generateServiceLevelIndicator({}, {
    serviceAggregation: false,  // Don't add this to the request rate of the service
    severity: 's3',  // Don't page SREs for this SLI
  }) + sliLibrary.get('ci_deleted_objects_processing').generateServiceLevelIndicator({}, {
    serviceAggregation: false,  // Don't add this to the request rate of the service
    severity: 's3',  // Don't page SREs for this SLI
  }),

  capacityPlanning: {
    saturation_dimensions: [
      { selector: selectors.serializeHash({ shard: shard.name }) }
      for shard in sidekiqHelpers.shards.listAll()
      if shard.capacityPlanning
    ],
    saturation_dimensions_keep_aggregate: false,
    components: [
      {
        name: 'rails_db_connection_pool',
        parameters: {
          ignore_outliers: [
            {
              start: '2021-01-01',
              end: '2023-04-10',
            },
          ],
        },
      },
      {
        name: 'kube_container_throttling',
        parameters: {
          ignore_outliers: [
            {
              // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/20615
              start: '2025-09-25',
              end: '2025-09-29',
            },
          ],
        },
      },
    ],
  },
})
