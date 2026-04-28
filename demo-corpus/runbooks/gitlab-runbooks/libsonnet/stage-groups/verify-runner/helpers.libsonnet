local panel = import 'grafana/time-series/panel.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';

local aggregatorLegendFormat(aggregator) = '{{ %s }}' % aggregator;
local aggregatorsLegendFormat(aggregators) = '%s' % std.join(' - ', std.map(aggregatorLegendFormat, aggregators));

local aggregationTimeSeries(
  title,
  query,
  aggregators=[],
  stack=true,
  thresholdSteps=[],
  description='',
      ) =
  local serializedAggregation = aggregations.serialize(aggregators);
  panel.timeSeries(
    title=(title % serializedAggregation),
    description=description,
    legendFormat=aggregatorsLegendFormat(aggregators),
    linewidth=2,
    fill=if stack then 10 else 0,
    stack=stack,
    query=(query % serializedAggregation),
    thresholdSteps=thresholdSteps,
  );

{
  aggregationTimeSeries:: aggregationTimeSeries,
}
