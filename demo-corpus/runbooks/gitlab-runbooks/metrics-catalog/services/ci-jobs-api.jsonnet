local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local haproxyComponents = import './lib/haproxy_components.libsonnet';
local sliLibrary = import 'gitlab-slis/library.libsonnet';
local serviceLevelIndicatorDefinition = import 'servicemetrics/service_level_indicator_definition.libsonnet';
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local dependOnPatroni = import 'inhibit-rules/depend_on_patroni.libsonnet';
local railsQueueingSli = import 'service-archetypes/helpers/rails_queueing_sli.libsonnet';

local railsSelector = { job: 'gitlab-rails', type: 'ci-jobs-api' };

metricsCatalog.serviceDefinition({
  type: 'ci-jobs-api',
  tier: 'sv',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],

  tags: ['golang', 'rails', 'puma', 'kube_container_rss'],

  contractualThresholds: {
    apdexRatio: 0.9,
    errorRatio: 0.005,
  },
  monitoringThresholds: {
    apdexScore: 0.995,
    errorRatio: 0.999,
  },
  otherThresholds: {
    // Deployment thresholds are optional, and when they are specified, they are
    // measured against the same multi-burn-rates as the monitoring indicators.
    // When a service is in violation, deployments may be blocked or may be rolled
    // back.
    deployment: {
      apdexScore: 0.995,
      errorRatio: 0.999,
    },

    mtbf: {
      apdexScore: 0.9985,
      errorRatio: 0.9998,
    },
  },
  serviceDependencies: {
    gitaly: true,
    'redis-sidekiq': true,
    'redis-cluster-cache': true,
    redis: true,
    patroni: true,
    pgbouncer: true,
    consul: true,
  },
  provisioning: {
    vms: false,
    kubernetes: true,
  },
  regional: true,
  kubeResources: {
    'ci-jobs-api': {
      kind: 'Deployment',
      containers: [
        'gitlab-workhorse',
        'webservice',
      ],
    },
  },
  serviceLevelIndicators: {
    workhorse: {
      userImpacting: true,
      serviceAggregation: false,
      featureCategory: 'not_owned',
      team: 'workhorse',
      description: |||
        Aggregation of most web requests that pass through workhorse, monitored via the HTTP interface.
        Excludes health, readiness and liveness requests. Some known slow requests, such as HTTP uploads,
        are excluded from the apdex score.
      |||,

      local workhorseSelector = {
        job: { oneOf: ['gitlab-workhorse-api', 'gitlab-workhorse'] },
        type: 'ci-jobs-api',
      },
      local healthCheckSelector = {
        route: { ne: ['^/-/health$', '^/-/(readiness|liveness)$'] },
      },

      apdex: histogramApdex(
        histogram='gitlab_workhorse_http_request_duration_seconds_bucket',
        selector=workhorseSelector + healthCheckSelector + {
          code: { nre: '5..' },
          fetched_external_url: { ne: 'true' },
        },
        satisfiedThreshold=60,
        metricsFormat='migrating'
      ),

      requestRate: rateMetric(
        counter='gitlab_workhorse_http_requests_total',
        selector=workhorseSelector,
      ),

      errorRate: rateMetric(
        counter='gitlab_workhorse_http_requests_total',
        selector=workhorseSelector + healthCheckSelector + {
          code: { re: '^5.*' },
        }
      ),

      significantLabels: ['region', 'method', 'route'],

      toolingLinks: [
        toolingLinks.continuousProfiler(service='workhorse-api'),
        toolingLinks.sentry(projectId=15),
        toolingLinks.kibana(title='Workhorse', index='workhorse', type='ci-jobs-api', slowRequestSeconds=10),
      ],

      dependsOn: dependOnPatroni.sqlComponents,
    },
  } + sliLibrary.get('rails_request').generateServiceLevelIndicator(railsSelector, {
    monitoringThresholds+: {
      apdexScore: 0.99,
    },

    toolingLinks: [
      toolingLinks.kibana(title='Rails', index='rails'),
    ],
    dependsOn: dependOnPatroni.sqlComponents,
  }) + railsQueueingSli(0.25, 1, selector={ type: 'ci-jobs-api' }, overrides={
    severity: 's2',
    experimental: false,
    monitoringThresholds+: {
      apdexScore: 0.995,
    },
  }),
  capacityPlanning: {
    components: [
      {
        name: 'ruby_thread_contention',
        parameters: {
          changepoints: [
            '2023-07-15',
          ],
        },
      },
      {
        name: 'rails_db_connection_pool ',
        parameters: {
          ignore_outliers: [
            {
              start: '2024-12-30',
              end: '2025-01-03',
            },
          ],
        },
      },
      {
        name: 'kube_go_memory',
        parameters: {
          ignore_outliers: [
            {
              start: '2025-12-08',
              end: '2025-12-10',
            },
          ],
        },
      },
    ],
  },
})
