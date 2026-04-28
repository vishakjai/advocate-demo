local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local gaugeMetric = metricsCatalog.gaugeMetric;
local rateMetric = metricsCatalog.rateMetric;
local errorCounterApdex = metricsCatalog.errorCounterApdex;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local combined = metricsCatalog.combined;

// Mimir operates across all stages and all environments,
// so we use special labels to merge environments and stages...
local staticLabels = {
  environment: 'ops',
  env: 'ops',
  stage: 'main',
};

local mimirServiceSelector = { type: 'mimir', namespace: 'mimir' };

metricsCatalog.serviceDefinition({
  type: 'mimir',
  tier: 'inf',
  tenants: ['metamonitoring'],
  team: 'observability',

  tags: ['mimir'],

  monitoringThresholds: {
    apdexScore: 0.95,
    errorRatio: 0.95,
  },
  /*
   * Our anomaly detection uses normal distributions and the monitoring service
   * is prone to spikes that lead to a non-normal distribution. For that reason,
   * disable ops-rate anomaly detection on this service.
   */
  disableOpsRatePrediction: true,

  // Thanos needs to self-monitor in Thanos
  // this should not be required for other services.
  dangerouslyThanosEvaluated: false,

  // No stages for Thanos
  serviceIsStageless: true,

  provisioning: {
    kubernetes: true,
    vms: false,
  },
  serviceDependencies: {
    monitoring: true,
  },
  kubeResources: {
    'mimir-querier': {
      kind: 'Deployment',
      containers: [
        'querier',
      ],
    },
    'mimir-query-frontend': {
      kind: 'Deployment',
      containers: [
        'query-frontend',
      ],
    },
    'mimir-query-scheduler': {
      kind: 'Deployment',
      containers: [
        'query-scheduler',
      ],
    },
    'mimir-distributor': {
      kind: 'Deployment',
      containers: [
        'distributor',
      ],
    },
    'mimir-gateway': {
      kind: 'Deployment',
      containers: [
        'nginx',
      ],
    },
    'mimir-ruler': {
      kind: 'Deployment',
      containers: [
        'ruler',
      ],
    },
    'mimir-alertmanager': {
      kind: 'StatefulSet',
      containers: [
        'alertmanager',
      ],
    },
    'mimir-compactor': {
      kind: 'StatefulSet',
      containers: [
        'compactor',
      ],
    },
    'mimir-ingester': {
      kind: 'StatefulSet',
      containers: [
        'ingester',
      ],
    },
    'mimir-store-gateway': {
      kind: 'StatefulSet',
      containers: [
        'store-gateway',
      ],
    },
    'mimir-chunks-cache': {
      kind: 'StatefulSet',
      containers: [
        'memcached',
      ],
    },
    'mimir-index-cache': {
      kind: 'StatefulSet',
      containers: [
        'memcached',
      ],
    },
    'mimir-metadata-cache': {
      kind: 'StatefulSet',
      containers: [
        'memcached',
      ],
    },
    'mimir-results-cache': {
      kind: 'StatefulSet',
      containers: [
        'memcached',
      ],
    },
    'mimir-consul': {
      kind: 'StatefulSet',
      containers: [
        'consul',
      ],
    },
  },
  serviceLevelIndicators: {

    // Shared by `mimir_querier` and `mimir_querier_frontend` SLIs
    local querierRouteSelector = { route: { re: 'prometheus_(api|prom)_v1_.+' } },

    mimir_querier: {
      staticLabels: staticLabels,
      severity: 's2',
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The querier is a stateless component that evaluates PromQL expressions by fetching time series and labels on the read path.
        The querier uses the store-gateway component to query the long-term storage and the ingester component to query recently written data.
        This SLI monitors the querier requests. 5xx responses are considered failures.
      |||,

      local mimirQuerySelector = mimirServiceSelector {
        job: 'mimir/querier',
      },

      apdex: histogramApdex(
        histogram='cortex_querier_request_duration_seconds_bucket',
        selector=mimirQuerySelector + querierRouteSelector,
        satisfiedThreshold=25.0,
      ),

      requestRate: rateMetric(
        counter='cortex_querier_request_duration_seconds_count',
        selector=mimirQuerySelector + querierRouteSelector,
      ),

      errorRate: rateMetric(
        counter='cortex_querier_request_duration_seconds_count',
        selector=mimirQuerySelector + querierRouteSelector { status_code: { re: '^5.*' } },
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Mimir Querier', index='mimir', matches={ 'kubernetes.container_name': 'querier' }),
      ],
    },

    mimir_query_frontend: {
      staticLabels: staticLabels,
      severity: 's2',
      team: 'observability',
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The query-frontend is a stateless component that provides the same API as the querier and can be used to accelerate the read path via caching.
        This SLI monitors the query-frontend requests. 5xx responses are considered failures.
      |||,

      local mimirQuerySelector = mimirServiceSelector {
        job: 'mimir/query-frontend',
      },

      apdex: histogramApdex(
        histogram='cortex_request_duration_seconds_bucket',
        selector=mimirQuerySelector + querierRouteSelector,
        satisfiedThreshold=25.0,
      ),

      requestRate: rateMetric(
        counter='cortex_request_duration_seconds_count',
        selector=mimirQuerySelector + querierRouteSelector,
      ),

      errorRate: rateMetric(
        counter='cortex_request_duration_seconds_count',
        selector=mimirQuerySelector + querierRouteSelector { status_code: { re: '^5.*' } },
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Mimir Query Frontend', index='mimir', matches={ 'kubernetes.container_name': 'query-frontend' }),
      ],
    },

    mimir_query_scheduler: {
      staticLabels: staticLabels,
      severity: 's2',
      team: 'observability',
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The query-scheduler is an optional, stateless component that retains a queue of queries to execute, and distributes the workload to available queriers.
        This enabled easier scaling of the query-frontends
        This SLI monitors the query-scheduler requests. 5xx responses are considered failures.
      |||,

      local mimirSchedulerSelector = mimirServiceSelector {
        job: 'mimir/query-scheduler',
      },

      apdex: histogramApdex(
        histogram='cortex_query_scheduler_queue_duration_seconds_bucket',
        selector=mimirSchedulerSelector,
        satisfiedThreshold=5.0,
      ),

      requestRate: rateMetric(
        counter='cortex_query_scheduler_queue_duration_seconds_count',
        selector=mimirSchedulerSelector
      ),

      errorRate: rateMetric(
        counter='cortex_query_scheduler_queue_duration_seconds_count',
        selector=mimirSchedulerSelector { status_code: { re: '^5.*' } }
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Mimir Query Scheduler', index='mimir', matches={ 'kubernetes.container_name': 'query-scheduler' }),
      ],
    },

    mimir_store_gateway: {
      staticLabels: staticLabels,
      severity: 's2',
      team: 'observability',
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The store-gateway component, which is stateful, queries blocks from long-term storage.
        On the read path, the querier and the ruler use the store-gateway when handling the query, whether the query comes from a user or from when a rule is being evaluated.
        This SLI monitors the store-gatewau requests. 5xx responses are considered failures.
      |||,

      local mimirStoreGatewaySelector = mimirServiceSelector {
        job: 'mimir/store-gateway',
        route: { re: '/gatewaypb\\\\.StoreGateway/.*' },
      },

      apdex: histogramApdex(
        histogram='cortex_request_duration_seconds_bucket',
        selector=mimirStoreGatewaySelector,
        satisfiedThreshold=25.0,
      ),

      requestRate: rateMetric(
        counter='cortex_request_duration_seconds_count',
        selector=mimirStoreGatewaySelector,
      ),

      errorRate: rateMetric(
        counter='cortex_request_duration_seconds_count',
        selector=mimirStoreGatewaySelector { status_code: { re: '^5.*' } }
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Mimir Store Gateway', index='mimir', matches={ 'kubernetes.container_name': 'store-gateway' }),
      ],
    },

    mimir_distributor: {
      staticLabels: staticLabels,
      severity: 's2',
      team: 'observability',
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The distributor is a stateless component that receives time-series data from remote-write requests via Prometheus or the Grafana agent.
        It validates the data for correctness and ensures that it is within the configured limits for a given tenant.
        The distributor then divides the data into batches and sends it to multiple ingesters in parallel, shards the series among ingesters, and replicates each series by the configured replication factor.
        By default, the configured replication factor is three.
        This SLI monitors the distributor requests. 5xx responses are considered failures.
      |||,

      local mimirQueryDistributorSelector = mimirServiceSelector {
        job: 'mimir/distributor',
        route: { oneOf: ['/distributor\\\\.Distributor/Push', '/httpgrpc.*', 'api_(v1|prom)_push', 'otlp_v1_metrics'] },
      },

      apdex: histogramApdex(
        histogram='cortex_request_duration_seconds_bucket',
        selector=mimirQueryDistributorSelector,
        satisfiedThreshold=0.5,
        toleratedThreshold=1.0,
      ),

      requestRate: rateMetric(
        counter='cortex_request_duration_seconds_count',
        selector=mimirQueryDistributorSelector,
      ),

      errorRate: rateMetric(
        counter='cortex_request_duration_seconds_count',
        selector=mimirQueryDistributorSelector { status_code: { re: '^5.*' } },
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Mimir Distributor', index='mimir', matches={ 'kubernetes.container_name': 'distributor' }),
      ],
    },

    mimir_ingester: {
      staticLabels: staticLabels,
      severity: 's2',
      team: 'observability',
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The ingester is a stateful component that writes incoming series to long-term storage on the write path and returns series samples for queries on the read path.
        Incoming time series data from distributors are temporarily stored in the ingester’s memory or offloaded to disk before being written to long-term storage.
        Eventually, all series are written to disk and periodically uploaded (by default every two hours) to the long-term storage.
        This SLI monitors the distributor requests. 5xx responses are considered failures.
      |||,

      local mimirIngesterQuerySelector = mimirServiceSelector {
        job: 'mimir/ingester',
        route: '/cortex.Ingester/Push',
      },

      apdex: histogramApdex(
        histogram='cortex_request_duration_seconds_bucket',
        selector=mimirIngesterQuerySelector,
        satisfiedThreshold=0.1,
        toleratedThreshold=1.0,
      ),

      requestRate: rateMetric(
        counter='cortex_request_duration_seconds_count',
        selector=mimirIngesterQuerySelector,
      ),

      errorRate: rateMetric(
        counter='cortex_request_duration_seconds_count',
        selector=mimirIngesterQuerySelector { status_code: { re: '^5.*' } },
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Mimir Ingester', index='mimir', matches={ 'kubernetes.container_name': 'ingester' }),
      ],
    },

    mimir_compactor: {
      staticLabels: staticLabels,
      severity: 's3',
      team: 'observability',
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The compactor increases query performance and reduces long-term storage usage by combining blocks.
        This SLI monitors the compactor operations for failures.
      |||,

      local mimirCompactorSelector = mimirServiceSelector {
        job: 'mimir/compactor',
      },

      requestRate: rateMetric(
        counter='cortex_compactor_group_compaction_runs_started_total',
        selector=mimirCompactorSelector
      ),

      errorRate: rateMetric(
        counter='cortex_compactor_group_compactions_failures_total',
        selector=mimirCompactorSelector
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Mimir Compactor', index='mimir', matches={ 'kubernetes.container_name': 'compactor' }),
      ],
    },

    mimir_ruler: {
      staticLabels: staticLabels,
      severity: 's2',
      team: 'observability',
      userImpacting: false,
      featureCategory: 'not_owned',
      description: |||
        The ruler component evaluates PromQL expressions defined in recording and alerting rules. Each tenant has a set of recording and alerting rules and can group those rules into namespaces.
        This SLI monitors the rulers evaluation failures.

        Missed rule evaluations result in missing datapoints in recording rules, those are also treated as errors in this SLI.
      |||,

      local mimirRulerSelector = mimirServiceSelector {
        job: 'mimir/ruler',
      },

      requestRate: rateMetric(
        counter='cortex_prometheus_rule_evaluations_total',
        selector=mimirRulerSelector
      ),

      errorRate: combined(
        [
          rateMetric(
            counter='cortex_prometheus_rule_evaluation_failures_total',
            selector=mimirRulerSelector
          ),
          rateMetric(
            counter='cortex_prometheus_rule_group_iterations_missed_total',
            selector=mimirRulerSelector
          ),
        ],
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='Mimir Ruler', index='mimir', matches={ 'kubernetes.container_name': 'ruler' }),
      ],
    },
  },
  skippedMaturityCriteria: {
    'Service exists in the dependency graph': 'Mimir is an independent internal observability tool. It fetches metrics from other services, but does not interact with them, functionally',
  },
})
