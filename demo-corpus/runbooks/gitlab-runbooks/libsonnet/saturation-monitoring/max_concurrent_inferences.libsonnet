local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;
local selectors = import 'promql/selectors.libsonnet';

{
  max_concurrent_inferences: resourceSaturationPoint({
    title: 'Maximum number of concurrent inferences to a large language model',
    severity: 's3',
    horizontallyScalable: false,
    appliesTo: ['ai-gateway'],
    burnRatePeriod: '10m',
    description: |||
      The maximum number of inferences (requests) we can concurrently make to a
      single LLM.

      Anthropic is enforcing different concurrency limits per model they provide.
      When we make a new request when we already have the maximum number of concurrent
      requests in flight, Anthropic responds with a 429. The client-library in the
      AI-gateway is set to retry once on errors.

      When Anthropic rejects the requests, this leads to a 500 error in the AI-gateway
      and Workhorse. This results in clients not getting a response (code suggestion).

      To fix this, we need to request a larger concurrency to Anthropic.
      Currently in the `#ext-anthropic` slack channel.

      Bear in mind that this metric is sampled at scrape time. So it is only an
      approximation of the actual number of requests in flight. We should assume the
      actual utilization is higher and request increases sooner.
    |||,
    grafana_dashboard_uid: 'max_concurrent_inferences',
    resourceLabels: ['model_engine', 'model_name'],
    // temporary flag to expand resource labels as the max aggregation labels
    // to retain saturation data across multiple labels.
    useResourceLabelsAsMaxAggregationLabels: true,
    query: |||
      sum by (%(aggregationLabels)s)(max_over_time(model_inferences_in_flight{%(selector)s}[%(rangeInterval)s]))
      /
      min by (%(aggregationLabels)s)(min_over_time(model_inferences_max_concurrent{%(selector)s}[%(rangeInterval)s]))
    |||,
    capacityPLanning: {
      strategy: 'quantile99_1h',
    },
    slos: {
      soft: 0.60,
      hard: 0.80,
    },
  }),

  max_concurrent_inferences_per_engine: resourceSaturationPoint({
    title: 'Maximum number of concurrent inferences to a large language model',
    severity: 's3',
    horizontallyScalable: false,
    appliesTo: ['ai-gateway'],
    burnRatePeriod: '10m',
    description: |||
      The maximum number of inferences (requests) we can concurrently make to a
      all models for a single provider (engine).

      Anthropic is enforcing different concurrency limits per model they provide.
      But across all models, we can not exceed the global limit that is equal to
      the largest allowed limit.

      When Anthropic rejects the requests, this leads to a 500 error in the AI-gateway
      and Workhorse. This results in clients not getting a response (code suggestion).

      To fix this, we need to request a larger concurrency to Anthropic.
      Currently in the `#ext-anthropic` slack channel.

      Bear in mind that this metric is sampled at scrape time. So it is only an
      approximation of the actual number of requests in flight. We should assume the
      actual utilization is higher and request increases sooner.
    |||,
    grafana_dashboard_uid: 'max_inferences_per_engine',
    resourceLabels: ['model_engine'],
    query: |||
      sum by (%(aggregationLabels)s)(max_over_time(model_inferences_in_flight{%(selector)s}[%(rangeInterval)s]))
      /
      max by (%(aggregationLabels)s)(min_over_time(model_inferences_max_concurrent{%(selector)s}[%(rangeInterval)s]))
    |||,
    capacityPLanning: {
      strategy: 'quantile99_1h',
    },
    slos: {
      soft: 0.60,
      hard: 0.80,
    },
  }),
}
