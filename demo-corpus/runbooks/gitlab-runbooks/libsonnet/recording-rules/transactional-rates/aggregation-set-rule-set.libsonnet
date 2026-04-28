local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local aggregationFilterExpr = import 'recording-rules/lib/aggregation-filter-expr.libsonnet';
local optionalOffset = import 'recording-rules/lib/optional-offset.libsonnet';
local recordedRatesLabel = (import 'recording-rules/transactional-rates/transactional-rates.libsonnet').recordedRatesLabel;
local upscaling = import 'recording-rules/lib/upscaling.libsonnet';

local directRateExpression(sourceMetricName, sourceAggregationSet, targetAggregationSet) =
  local sourceSelector = selectors.serializeHash(sourceAggregationSet.selector);
  local targetAggregationLabels = aggregations.serialize(targetAggregationSet.labels);

  if sourceMetricName != null then
    // The difference between this and rate-rule-set.libsonnet is that we don't
    // filter out zeros. We want both metrics to exist:
    // if an error-rate is zero, and the ops rate is not, we need to be able to have a 0% error ratio
    |||
      sum by (%(targetAggregationLabels)s) (
        (%(sourceMetricName)s{%(sourceSelector)s}%(optionalOffset)s)%(aggregationFilterExpr)s
      )
    ||| % {
      sourceMetricName: sourceMetricName,
      targetAggregationLabels: targetAggregationLabels,
      sourceSelector: sourceSelector,
      aggregationFilterExpr: aggregationFilterExpr(targetAggregationSet),
      optionalOffset: optionalOffset(targetAggregationSet.offset),
    }
  else null;


local visitor(metricNameFn, upscaledRatesFn) = {
  metricName(aggregationSet, required=false): metricNameFn(aggregationSet, required),
  rateExpression(sourceAggregationSet, targetAggregationSet):
    local targetAggregationSetWithRecordedRate = targetAggregationSet { labels+: [recordedRatesLabel] };
    local directExpr = directRateExpression(metricNameFn(sourceAggregationSet, false), sourceAggregationSet, targetAggregationSetWithRecordedRate);
    upscaledRatesFn(sourceAggregationSet, targetAggregationSetWithRecordedRate, directExpr),
};
local errorRates(burnRate) =
  visitor(
    function(aggregationSet, required=false) aggregationSet.getErrorRatesMetricForBurnRate(burnRate, required),
    function(sourceAggregationSet, targetAggregationSet, directExpr)
      upscaling.combinedTransactionalErrorRatesExpression(sourceAggregationSet, targetAggregationSet, burnRate, directExpr)
  );

local apdexRates(burnRate) =
  visitor(
    function(aggregationSet, required=false) aggregationSet.getApdexRatesMetricForBurnRate(burnRate, required),
    function(sourceAggregationSet, targetAggregationSet, directExpr)
      upscaling.combinedTransactionalApdexRatesExpression(sourceAggregationSet, targetAggregationSet, burnRate, directExpr)
  );


local getRecordingRuleDefinitions(visitor, sourceAggregationSet, targetAggregationSet) =
  local metricName = visitor.metricName(targetAggregationSet, required=false);
  if metricName != null then
    [
      std.prune({
        record: metricName,
        labels: targetAggregationSet.recordingRuleStaticLabels,
        expr: visitor.rateExpression(sourceAggregationSet, targetAggregationSet),
      }),
    ]
  else [];


function(
  sourceAggregationSet, targetAggregationSet, burnRate
)
  getRecordingRuleDefinitions(errorRates(burnRate), sourceAggregationSet, targetAggregationSet) +
  getRecordingRuleDefinitions(apdexRates(burnRate), sourceAggregationSet, targetAggregationSet)
