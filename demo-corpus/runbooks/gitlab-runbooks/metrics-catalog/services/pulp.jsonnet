local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local gaugeMetric = metricsCatalog.gaugeMetric;

metricsCatalog.serviceDefinition({
  type: 'pulp',
  tier: 'inf',
  tenants: ['gitlab-pre', 'gitlab-ops'],
  defaultTenant: 'gitlab-ops',

  tags: ['cloud-sql'],

  serviceIsStageless: true,

  provisioning: {
    kubernetes: true,
    vms: false,
  },

  monitoringThresholds: {
    errorRatio: 0.999,
    apdexScore: 0.999,
  },

  regional: false,

  serviceDependencies: {
    'cloud-sql': true,
    kube: true,
    memorystore: true,
  },

  kubeConfig: {},
  kubeResources: {
    api: {
      kind: 'Deployment',
      containers: [
        'api',
      ],
    },
    content: {
      kind: 'Deployment',
      containers: [
        'content',
      ],
    },
    'ingress-nginx-controller': {
      kind: 'Deployment',
      containers: [
        'controller',
      ],
    },
    'sql-proxy': {
      kind: 'Deployment',
      containers: [
        'sqlproxy',
      ],
    },
    worker: {
      kind: 'Deployment',
      containers: [
        'worker',
      ],
    },
  },

  local sliCommon = {
    userImpacting: true,
    team: 'build',
    featureCategory: 'omnibus_package',
  },

  serviceLevelIndicators: {

    local pulpQuerySelector = { namespace: 'pulp' },

    pulp_nginx: sliCommon {
      description: |||
        Pulp uses nginx ingress controller for load balancing.
      |||,

      apdex: histogramApdex(
        histogram='nginx_ingress_controller_request_duration_seconds_bucket',
        selector=pulpQuerySelector,
        satisfiedThreshold=10,
        metricsFormat='migrating'
      ),

      requestRate: rateMetric(
        counter='nginx_ingress_controller_requests',
        selector=pulpQuerySelector,
      ),

      errorRate: rateMetric(
        counter='nginx_ingress_controller_requests',
        selector=pulpQuerySelector { status: { re: '^5.*' } },
      ),

      significantLabels: ['method', 'path', 'status'],
    },

    pulp_cloudsql: sliCommon {
      description: |||
        Pulp uses a GCP CloudSQL PostgreSQL instance.
      |||,
      severity: 's3',

      requestRate: gaugeMetric(
        gauge='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_statements_executed_count',
        selector={
          database_id: { re: '.+:pulp-.+' },
        }
      ),
      significantLabels: ['database_id', 'database', 'operation_type'],
      serviceAggregation: false,
      toolingLinks: [
        function(options) [{ title: 'Kibana: Pulp (ops) logs', url: 'https://nonprod-log.gitlab.net/app/r/s/mwt5y', tool: 'kibana', type: 'log' }],
        function(options) [{ title: 'Kibana: Pulp (pre) logs', url: 'https://nonprod-log.gitlab.net/app/r/s/qarx2', tool: 'kibana', type: 'log' }],
        function(options) [{ title: 'Kibana: Pulp (ops) requests', url: 'https://nonprod-log.gitlab.net/app/r/s/9lBli', tool: 'kibana', type: 'log' }],
        function(options) [{ title: 'Kibana: Pulp (pre) requests', url: 'https://nonprod-log.gitlab.net/app/r/s/PsVn5', tool: 'kibana', type: 'log' }],
        toolingLinks.cloudSQL('pulp-ce6e8d88', 'gitlab-pre'),
      ],
      // This is based on stackdriver metrics, that are labeled with the `type='monitoring'
      emittedBy: ['monitoring'],
    },

    pulp_gcs: sliCommon {
      description: |||
        Pulp uses a GCS bucket for package storage.
      |||,
      severity: 's3',

      requestRate: gaugeMetric(
        gauge='stackdriver_gcs_bucket_storage_googleapis_com_api_request_count',
        selector={
          bucket_name: 'packages-pre',
        }
      ),
      significantLabels: ['bucket_name', 'method'],
      serviceAggregation: false,
      toolingLinks: [
        toolingLinks.gcs('packages-pre', 'gitlab-pre'),
      ],
      emittedBy: ['monitoring'],
    },

    pulp_redis: sliCommon {
      description: |||
        Pulp uses a GCP Redis Memorystore instance for caching and session management.
      |||,
      severity: 's3',

      requestRate: gaugeMetric(
        gauge='stackdriver_redis_instance_redis_googleapis_com_commands_calls',
        selector={
          instance_id: { re: '.+/pulp-redis' },
        }
      ),
      significantLabels: ['instance_id'],
      serviceAggregation: false,
      toolingLinks: [
        toolingLinks.memoryStore('us-east1', 'pulp-redis', 'gitlab-pre'),
      ],
      emittedBy: ['monitoring'],
    },

    pulp_app_api: sliCommon {
      description: |||
        Pulp application API service request latency and error rates.
      |||,

      apdex: histogramApdex(
        histogram='api_request_duration_milliseconds_bucket',
        selector=pulpQuerySelector,
        toleratedThreshold=10000,
        satisfiedThreshold=2000,
        metricsFormat='migrating',
        unit='ms'
      ),

      requestRate: rateMetric(
        counter='api_request_duration_milliseconds_count',
        selector=pulpQuerySelector,
      ),

      errorRate: rateMetric(
        counter='api_request_duration_milliseconds_count',
        selector=pulpQuerySelector { http_status_code: { re: '^5.*' } },
      ),

      significantLabels: ['http_method', 'http_target', 'http_status_code'],
    },

    pulp_app_content: sliCommon {
      description: |||
        Pulp application content API request latency and error rates.
      |||,

      apdex: histogramApdex(
        histogram='content_request_duration_milliseconds_bucket',
        selector=pulpQuerySelector,
        satisfiedThreshold=10000,
        metricsFormat='migrating',
        unit='ms'
      ),

      requestRate: rateMetric(
        counter='content_request_duration_milliseconds_count',
        selector=pulpQuerySelector,
      ),

      errorRate: rateMetric(
        counter='content_request_duration_milliseconds_count',
        selector=pulpQuerySelector { http_status_code: { re: '^5.*' } },
      ),

      significantLabels: ['http_method', 'http_route', 'http_status_code'],
    },
  },
})
