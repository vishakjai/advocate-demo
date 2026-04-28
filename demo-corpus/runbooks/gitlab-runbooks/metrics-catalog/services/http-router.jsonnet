local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'http-router',
  tier: 'lb',
  // Metrics are collected in ops and relabelled with `env` and `environment`
  // based on their intended environment pairing.
  tenants: ['gitlab-ops'],
  tenantEnvironmentTargets: ['gprd', 'gstg'],

  monitoringThresholds: {
    errorRatio: 0.99999,
  },
  shards: ['catchall', 'tail-worker'],
  monitoring: {
    shard: {
      enabled: true,
    },
  },
  serviceDependencies: {
    frontend: true,
    nat: true,
  },
  provisioning: {
    kubernetes: false,
    vms: false,
  },
  serviceIsStageless: true,

  tags: ['cloudflare-worker'],

  serviceLevelIndicators: {
    worker_requests: {
      severity: 's2',
      team: 'cells_infrastructure',
      userImpacting: true,
      featureCategory: 'not_owned',
      description: |||
        Aggregation of request that are flowing through the `http-router`.

        Errors on this SLI may indicate issues within the deployed `http-router`
        codebase as errors are limited to those originating inside of the worker.

        See: https://runbooks.gitlab.com/http-router/logging/
      |||,

      requestRate: rateMetric(
        counter='cloudflare_worker_requests_count',
      ),
      errorRate: rateMetric(
        counter='cloudflare_worker_errors_count',
      ),

      significantLabels: ['script_name'],

      toolingLinks: std.flattenArrays([
        [
          toolingLinks.cloudflareWorker.logs.live(scriptName=scriptName),
          toolingLinks.cloudflareWorker.logs.historical(scriptName=scriptName),
          toolingLinks.cloudflareWorker.metrics.view(scriptName=scriptName),
        ]
        for scriptName in [
          // catchall shard (legacy naming)
          // TODO: Remove these once catchall workers are renamed to http-router-{env}-catchall
          'production-gitlab-com-cells-http-router',
          'staging-gitlab-com-cells-http-router',
        ]
      ]) + [
        toolingLinks.cloudflareWorker.observability.visualization(
          title='cache hit ratio: staging-gitlab-com-cells-http-router',
          url='https://dash.cloudflare.com/852e9d53d0f8adbd9205389356f2303d/observability/queries/r0dhkdccke0bp219gkkcqhp6/visualizations?filters=%5B%7B%22key%22%3A%22%24metadata.service%22%2C%22operation%22%3A%22eq%22%2C%22value%22%3A%22staging-gitlab-com-cells-http-router%22%2C%22type%22%3A%22string%22%7D%5D&filterCombination=%22and%22&calculations=%5B%7B%22operator%22%3A%22count%22%7D%5D&groupBys=%5B%7B%22type%22%3A%22string%22%2C%22value%22%3A%22cache%22%7D%5D&orderBy=%7B%22value%22%3A%22count%22%2C%22order%22%3A%22desc%22%2C%22limit%22%3A10%7D&timeframe=1h&conditions=%7B%7D&conditionCombination=%22and%22&alertTiming=%7B%22interval%22%3A300%2C%22window%22%3A900%2C%22timeBeforeFiring%22%3A600%2C%22timeBeforeResolved%22%3A600%7D',
        ),
        toolingLinks.cloudflareWorker.observability.visualization(
          title='cache hit ratio: production-gitlab-com-cells-http-router',
          url='https://dash.cloudflare.com/852e9d53d0f8adbd9205389356f2303d/observability/queries/xo7utwtnb51ygix2gt2qeeui/visualizations?filters=%5B%7B%22key%22%3A%22%24metadata.service%22%2C%22operation%22%3A%22eq%22%2C%22value%22%3A%22production-gitlab-com-cells-http-router%22%2C%22type%22%3A%22string%22%7D%5D&filterCombination=%22and%22&calculations=%5B%7B%22operator%22%3A%22count%22%7D%5D&groupBys=%5B%7B%22type%22%3A%22string%22%2C%22value%22%3A%22cache%22%7D%5D&orderBy=%7B%22value%22%3A%22count%22%2C%22order%22%3A%22desc%22%2C%22limit%22%3A10%7D&timeframe=1h&conditions=%7B%7D&conditionCombination=%22and%22&alertTiming=%7B%22interval%22%3A300%2C%22window%22%3A900%2C%22timeBeforeFiring%22%3A600%2C%22timeBeforeResolved%22%3A600%7D',
        ),
      ],
    },
  },
  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'Logs from CloudFlare workers are stored and accessible in CloudFlare through the UI. See https://developers.cloudflare.com/workers/observability/logs/workers-logs/',
  },
})
