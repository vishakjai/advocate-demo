local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local aggregationSetRateExpression = import 'recording-rules/aggregation-set-rate-expression.libsonnet';
local aggregationFilterExpr = import 'recording-rules/lib/aggregation-filter-expr.libsonnet';
local optionalOffset = import 'recording-rules/lib/optional-offset.libsonnet';
local upscaling = import 'recording-rules/lib/upscaling.libsonnet';
local strings = import 'utils/strings.libsonnet';

local getDirectExpr(sourceAggregationSet, targetAggregationSet, burnRate) =
  local targetOpsRateMetric = targetAggregationSet.getOpsRateMetricForBurnRate(burnRate);
  local targetErrorRateMetric = targetAggregationSet.getErrorRateMetricForBurnRate(burnRate);
  local targetAggregationLabels = aggregations.serialize(targetAggregationSet.labels);
  local sourceSelector = selectors.serializeHash(sourceAggregationSet.selector);

  local sourceErrorRateMetric = sourceAggregationSet.getErrorRateMetricForBurnRate(burnRate, required=true);

  local errorRateExpr = aggregationSetRateExpression(sourceAggregationSet, targetAggregationSet, burnRate, sourceErrorRateMetric);

  local sourceOpsRateMetric = sourceAggregationSet.getOpsRateMetricForBurnRate(burnRate);
  local opsRateExpr = aggregationSetRateExpression(sourceAggregationSet, targetAggregationSet, burnRate, sourceOpsRateMetric);

  |||
    sum by (%(targetAggregationLabels)s)(
      %(errorRateExpr)s
    )
    /
    sum by (%(targetAggregationLabels)s)(
      %(opsRateExpr)s
      and
      %(errorRateExpr)s
    )
  ||| % {
    targetAggregationLabels: targetAggregationLabels,
    errorRateExpr: strings.chomp(errorRateExpr),
    opsRateExpr: strings.chomp(opsRateExpr),
  };

{
  aggregationSetErrorRatioRuleSet(sourceAggregationSet, targetAggregationSet, burnRate)::
    local targetErrorRatioMetric = targetAggregationSet.getErrorRatioMetricForBurnRate(burnRate);

    if targetErrorRatioMetric == null then
      []
    else
      local sourceHasBurnRate = std.member(sourceAggregationSet.getBurnRates(), burnRate);
      local directExpr = if sourceHasBurnRate then
        getDirectExpr(sourceAggregationSet, targetAggregationSet, burnRate);
      [
        std.prune({
          record: targetErrorRatioMetric,
          labels: targetAggregationSet.recordingRuleStaticLabels,
          expr: upscaling.combinedErrorRatioExpression(sourceAggregationSet, targetAggregationSet, burnRate, directExpr),
        }),
      ],
}
