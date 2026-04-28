local selectors = import 'promql/selectors.libsonnet';
local aggregationFilterExpr = import 'recording-rules/lib/aggregation-filter-expr.libsonnet';
local optionalOffset = import 'recording-rules/lib/optional-offset.libsonnet';

local wrapSourceExpression(sourceAggregationSet, targetAggregationSet, sourceMetricName) =
  local sourceSelector = selectors.serializeHash(sourceAggregationSet.selector);
  local sourceMetric = '%(sourceMetricName)s{%(sourceSelector)s}%(optionalOffset)s' % {
    sourceMetricName: sourceMetricName,
    optionalOffset: optionalOffset(targetAggregationSet.offset),
    sourceSelector: sourceSelector,
  };

  if std.objectHas(sourceAggregationSet, 'wrapSourceExpressionFormat') then
    sourceAggregationSet.wrapSourceExpressionFormat % [sourceMetric]
  else
    sourceMetric;

function(sourceAggregationSet, targetAggregationSet, burnRate, sourceMetricName)
  '(%(sourceExpression)s >= 0)%(aggregationFilterExpr)s' % {
    sourceExpression: wrapSourceExpression(sourceAggregationSet, targetAggregationSet, sourceMetricName),
    aggregationFilterExpr: aggregationFilterExpr(targetAggregationSet),
  }
