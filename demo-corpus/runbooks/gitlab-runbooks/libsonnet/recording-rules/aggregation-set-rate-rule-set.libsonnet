local aggregations = import 'promql/aggregations.libsonnet';
local aggregationSetRateExpression = import 'recording-rules/aggregation-set-rate-expression.libsonnet';
local upscaling = import 'recording-rules/lib/upscaling.libsonnet';
local strings = import 'utils/strings.libsonnet';

local getDirectRateExpression(sourceAggregationSet, targetAggregationSet, burnRate, visitor) =
  local sourceMetricName = visitor.metricName(sourceAggregationSet, burnRate, required=false);
  local targetAggregationLabels = aggregations.serialize(targetAggregationSet.labels);
  local rateExpr = aggregationSetRateExpression(sourceAggregationSet, targetAggregationSet, burnRate, sourceMetricName);
  if sourceMetricName != null then
    |||
      sum by (%(targetAggregationLabels)s) (
        %(rateExpr)s
      )
    ||| % {
      targetAggregationLabels: targetAggregationLabels,
      rateExpr: rateExpr,
    };

local errorRateVisitor = {
  metricName(aggregationSet, burnRate, required=false)::
    aggregationSet.getErrorRateMetricForBurnRate(burnRate, required),

  getRateExpression(sourceAggregationSet, targetAggregationSet, burnRate)::
    local directExpr = getDirectRateExpression(sourceAggregationSet, targetAggregationSet, burnRate, self);
    upscaling.combinedErrorRateExpression(sourceAggregationSet, targetAggregationSet, burnRate, directExpr),
};

local opsRateVisitor = {
  metricName(aggregationSet, burnRate, required=false)::
    aggregationSet.getOpsRateMetricForBurnRate(burnRate, required),

  getRateExpression(sourceAggregationSet, targetAggregationSet, burnRate)::
    local directExpr = getDirectRateExpression(sourceAggregationSet, targetAggregationSet, burnRate, self);
    upscaling.combinedOpsRateExpression(sourceAggregationSet, targetAggregationSet, burnRate, directExpr),
};

// Generates the recording rule YAML when required. Returns an array of 0 or more definitions
local getRecordingRuleDefinitions(sourceAggregationSet, targetAggregationSet, burnRate, visitor) =
  local targetMetric = visitor.metricName(targetAggregationSet, burnRate, required=false);

  if targetMetric == null then
    []
  else
    [
      std.prune(
        {
          record: targetMetric,
          labels: targetAggregationSet.recordingRuleStaticLabels,
          expr: visitor.getRateExpression(sourceAggregationSet, targetAggregationSet, burnRate),
        },
      ),
    ];

{
  /** Aggregates Ops Rates and Error Rates between aggregation sets  */
  aggregationSetRateRuleSet(sourceAggregationSet, targetAggregationSet, burnRate)::
    getRecordingRuleDefinitions(sourceAggregationSet, targetAggregationSet, burnRate, errorRateVisitor)
    +
    getRecordingRuleDefinitions(sourceAggregationSet, targetAggregationSet, burnRate, opsRateVisitor),
}
