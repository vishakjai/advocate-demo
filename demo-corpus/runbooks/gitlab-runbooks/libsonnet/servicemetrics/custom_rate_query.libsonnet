local aggregations = import 'promql/aggregations.libsonnet';

{
  // A custom rate query allows arbitrary PromQL to be used as a rate query
  // This can be helpful if the metric is exposed as a gauge or in another manner
  customRateQuery(
    query,
  ):: {
    query: query,
    useRecordingRuleRegistry:: false,
    aggregatedRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      // Note that we ignore the rangeInterval, selectors, offset, and withoutLabels for now
      // TODO: handle those better, if we can
      local queryText = query % {
        burnRate: rangeInterval,
        aggregationLabels: aggregations.serialize(aggregationLabels),
      };
      aggregations.aggregateOverQuery('sum', aggregationLabels, queryText),
    metricNames: [],
  },
}
