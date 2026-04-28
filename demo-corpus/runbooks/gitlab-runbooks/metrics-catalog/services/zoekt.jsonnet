local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local histogramApdex = metricsCatalog.histogramApdex;
local successCounterApdex = metricsCatalog.successCounterApdex;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'zoekt',
  tier: 'inf',
  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.9999,
  },
  provisioning: {
    kubernetes: true,
    vms: false,
  },
  kubeResources: {
    'gitlab-zoekt': {
      kind: 'StatefulSet',
      containers: [
        'zoekt-indexer',
        'zoekt-webserver',
        'zoekt-internal-gateway',
      ],
    },
    'gitlab-zoekt-gateway': {
      kind: 'Deployment',
      containers: [
        'zoekt-external-gateway',
      ],
    },
  },
  serviceDependencies: {
    zoekt: true,
  },
  serviceIsStageless: true,
  serviceLevelIndicators: {
    zoekt_searching: {
      userImpacting: true,
      featureCategory: 'global_search',
      description: |||
        Aggregation of all search queries on GitLab.com, as measured from exact code search (backed by Zoekt).
      |||,
      apdex: histogramApdex(
        histogram='zoekt_search_duration_seconds_bucket',
        selector={ container: 'zoekt-webserver' },
        satisfiedThreshold=5.0,  // https://gitlab.com/gitlab-org/gitlab/-/blob/344b607c1539b7db4b9bab94c6f7fb06402255e1/lib/gitlab/metrics/global_search_slis.rb#L15-15
        toleratedThreshold=10.0,
        metricsFormat='migrating',
      ),
      requestRate: rateMetric(
        counter='zoekt_search_requests_total',
        selector={ container: 'zoekt-webserver' },
      ),
      errorRate: rateMetric(
        counter='zoekt_search_failed_total',
        selector={ container: 'zoekt-webserver' },
      ),
      emittedBy: [],
      serviceAggregation: true,
      severity: 's3',  // Don't page SREs for this SLI
      significantLabels: ['container'],
      toolingLinks: [
        toolingLinks.kibana(title='Exact code search', index='zoekt', includeMatchersForPrometheusSelector=false),
        function(options) [{ title: '📊 Kibana: Zoekt Dashboard', url: 'https://log.gprd.gitlab.net/app/r/s/pZFVV' }],
      ],
    },
    zoekt_tasks: {
      userImpacting: false,
      featureCategory: 'global_search',
      description: |||
        Zoekt indexing task processing SLI measuring request rate, error rate, and apdex
        for tasks enqueued to Zoekt nodes. Does not directly impact user-facing search
        performance, but affects search index freshness.
      |||,
      apdex: successCounterApdex(
        successRateMetric='gitlab_sli_search_zoekt_tasks_apdex_success_total',
        operationRateMetric='gitlab_sli_search_zoekt_tasks_apdex_total',
      ),
      requestRate: rateMetric(
        counter='gitlab_sli_search_zoekt_tasks_requests_total',
      ),
      errorRate: rateMetric(
        counter='gitlab_sli_search_zoekt_tasks_error_total',
      ),
      significantLabels: ['zoekt_node', 'task_type'],
      toolingLinks: [],
      serviceAggregation: false,
      severity: 's3',
    },
  },
  useConfidenceLevelForSLIAlerts: '98%',
  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'logs are available at https://log.gprd.gitlab.net/app/r/s/U9Av8, but not linked to SLIs as there are no SLIs for now.',
  },
})
