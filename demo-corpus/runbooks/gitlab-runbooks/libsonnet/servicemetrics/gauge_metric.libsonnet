local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local optionalOffset = import 'recording-rules/lib/optional-offset.libsonnet';
local metric = import 'servicemetrics/metric.libsonnet';
local metricLabelsSelectorsMixin = (import './metrics-mixin.libsonnet').metricLabelsSelectorsMixin;

{
  // A rate that is precalcuated, not stored as a counter
  // Some metrics from stackdriver are presented in this form
  gaugeMetric(
    gauge,
    selector={},
    samplingInterval=1  // in seconds
  ):: metric.new({
    useRecordingRuleRegistry:: false,
    selector: selector,

    local baseSelector = selector,  // alias
    aggregatedRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      local mergedSelectors = selectors.without(selectors.merge(baseSelector, selector), withoutLabels);
      local avg = 'avg_over_time(%(gauge)s{%(selectors)s}[%(rangeInterval)s]%(optionalOffset)s)' % {
        gauge: gauge,
        selectors: selectors.serializeHash(mergedSelectors),
        rangeInterval: rangeInterval,
        optionalOffset: optionalOffset(offset),
      };
      local query = if samplingInterval == 1 then avg else '%(avg)s / %(interval)i' % {
        avg: avg,
        interval: samplingInterval,
      };

      aggregations.aggregateOverQuery('sum', aggregationLabels, query),
  } + metricLabelsSelectorsMixin(selector, [gauge])),
}
