local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local optionalOffset = import 'recording-rules/lib/optional-offset.libsonnet';

local reflectedRuleSet(aggregationSet, burnRate, extraSelector, staticLabels, ratioMetricFn, numeratorNameFn, denominatorNameFn) =
  local ratioMetric = ratioMetricFn(burnRate);
  if ratioMetric == null then []
  else
    local denominatorRate = denominatorNameFn(burnRate, required=true);
    local numeratorRate = numeratorNameFn(burnRate, required=true);
    local aggregationLabels = std.filter(function(label) !std.objectHas(staticLabels, label), aggregationSet.labels);
    local selector = selectors.mergeAll([aggregationSet.selector, staticLabels, extraSelector]);
    local formatConfig = {
      denominator: denominatorRate,
      numerator: numeratorRate,
      selector: selectors.serializeHash(selector),
      aggregationLabels: aggregations.serialize(aggregationLabels),
      optionalOffset: optionalOffset(aggregationSet.offset),
    };
    local directExpr = |||
      sum by (%(aggregationLabels)s) (
        %(numerator)s{%(selector)s}%(optionalOffset)s
      )
      /
      sum by (%(aggregationLabels)s) (
        %(denominator)s{%(selector)s}%(optionalOffset)s
      )
    ||| % formatConfig;

    [{
      record: ratioMetric,
      expr: directExpr,
      [if std.length(std.objectFields(staticLabels)) > 0 then 'labels']: staticLabels,
    }];


{
  // Aggregates apdex scores internally within an aggregation set
  aggregationSetApdexRatioReflectedRuleSet(aggregationSet, burnRate, extraSelector={}, staticLabels={})::
    reflectedRuleSet(
      aggregationSet,
      burnRate,
      extraSelector,
      staticLabels,
      ratioMetricFn=aggregationSet.getApdexRatioMetricForBurnRate,
      numeratorNameFn=aggregationSet.getApdexSuccessRateMetricForBurnRate,
      denominatorNameFn=aggregationSet.getApdexWeightMetricForBurnRate,
    ),

  aggregationSetErrorRatioReflectedRuleSet(aggregationSet, burnRate, extraSelector={}, staticLabels={})::
    reflectedRuleSet(
      aggregationSet,
      burnRate,
      extraSelector,
      staticLabels,
      ratioMetricFn=aggregationSet.getErrorRatioMetricForBurnRate,
      numeratorNameFn=aggregationSet.getErrorRateMetricForBurnRate,
      denominatorNameFn=aggregationSet.getOpsRateMetricForBurnRate,
    ),
}
