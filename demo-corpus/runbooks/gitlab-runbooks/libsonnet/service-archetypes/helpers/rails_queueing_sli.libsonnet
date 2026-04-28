local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;

function(satisfiedThreshold, toleratedThreshold, selector={}, overrides={})
  {
    rails_queueing: {
      useConfidenceLevelForSLIAlerts: '98%',
      userImpacting: true,
      serviceAggregation: false,  // The requests are already counted in the `puma/rails_request` SLI.
      description: |||
        Apdex for time workhorse spends waiting for a free Puma worker.  When this alerts, a noticeable proportion of requests are arriving a Puma when there are no free workers, and thus queue for processing until a worker is free.

        Such queuing adds latency to the request which will often be user visible.

        Typically other apdex alerts will also be out of spec at the same time; this SLI adds signal that queuing is part of the problem, rather than only being slow processing requests with spare capacity in Puma for other requests.

        It typically indicates higher use of the system than it has been provisioned to handle; it can be resolved by either adding Puma workers (pods and nodes) or by finding high RPS traffic that can be eliminated.
      |||,

      requestRate: rateMetric(
        counter='gitlab_rails_queue_duration_seconds_count',
        selector=selector,
      ),

      apdex: histogramApdex(
        histogram='gitlab_rails_queue_duration_seconds_bucket',
        selector=selector,
        satisfiedThreshold=satisfiedThreshold,
        toleratedThreshold=toleratedThreshold,
        metricsFormat='migrating',
      ),

      significantLabels: [],
    } + overrides,
  }
