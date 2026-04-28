local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local joinExpr(targetAggregationSet) =
  if !std.objectHas(targetAggregationSet, 'joinSource') then
    ''
  else
    local selector = if std.objectHas(targetAggregationSet.joinSource, 'selector') then
      targetAggregationSet.joinSource.selector
    else
      {};

    local requiredLabelsFromJoin = targetAggregationSet.joinSource.labels + targetAggregationSet.joinSource.on;
    ' * on(%(joinOn)s) group_left(%(labels)s) (group by (%(aggregatedLabels)s) (%(metric)s{%(selector)s}))' % {
      joinOn: aggregations.serialize(std.set(targetAggregationSet.joinSource.on)),
      labels: aggregations.serialize(std.set(targetAggregationSet.joinSource.labels)),
      aggregatedLabels: aggregations.serialize(std.set(requiredLabelsFromJoin)),
      metric: targetAggregationSet.joinSource.metric,
      selector: selectors.serializeHash(selector),
    };

function(targetAggregationSet)
  local aggregationFilter = targetAggregationSet.aggregationFilter;

  // For service level aggregations, we need to filter out any SLIs which we don't want to include
  // in the service level aggregation.
  // These are defined in the SLI with `aggregateToService:false`

  // If multiple aggregation filters are defined, they are ANDed together
  joinExpr(targetAggregationSet) + if aggregationFilter != null then
    ' and on(component, type) (gitlab_component_service:mapping{%(selector)s})' % {
      selector: selectors.serializeHash(targetAggregationSet.selector {
        [f + '_aggregation']: 'yes'
        for f in if std.isArray(aggregationFilter) then aggregationFilter else [aggregationFilter]
      }),
    }
  else
    ''
