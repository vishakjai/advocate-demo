local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local ignoredComponentJoinLabels = ['stage_group', 'component'];
local ignoreCondition(ignoreComponents) =
  if ignoreComponents then
    'unless on (%s) gitlab:ignored_component:stage_group' % [aggregations.serialize(ignoredComponentJoinLabels)]
  else
    '';

local combinedRatio(aggregationSet, range, groupSelectors, aggregationLabels, ignoreComponents) =
  |||
    clamp_max(
      sum by (%(aggregations)s)(
        sum by (%(aggregationsIncludingComponent)s) (
          label_replace(
            sum_over_time(
              %(apdexSuccess)s{%(selectorHash)s}[%(range)s]
            ), 'sli_kind', 'apdex', '', ''
          )
          or
          label_replace(
            sum_over_time(
              %(opsRate)s{%(selectorHash)s}[%(range)s]
            )
            -
            sum_over_time(
              %(errorRate)s{%(selectorHash)s}[%(range)s]
            ), 'sli_kind', 'error', '', ''
          )
        ) %(ignoreCondition)s
      )
      /
      sum by (%(aggregations)s)(
        sum by (%(aggregationsIncludingComponent)s) (
          label_replace(
            sum_over_time(
              %(apdexWeight)s{%(selectorHash)s}[%(range)s]
            ),
            'sli_kind', 'apdex', '', ''
          )
          or
          label_replace(
            sum_over_time(
              %(opsRate)s{%(selectorHash)s}[%(range)s]
            )
            and sum_over_time(%(errorRate)s{%(selectorHash)s}[%(range)s]),
            'sli_kind', 'error', '', ''
          )
        ) %(ignoreCondition)s
      ),
    1)
  ||| % {
    apdexSuccess: aggregationSet.getApdexSuccessRateMetricForBurnRate('1h'),
    apdexWeight: aggregationSet.getApdexWeightMetricForBurnRate('1h'),
    opsRate: aggregationSet.getOpsRateMetricForBurnRate('1h'),
    errorRate: aggregationSet.getErrorRateMetricForBurnRate('1h'),
    selectorHash: selectors.serializeHash(groupSelectors),
    range: range,
    aggregations: aggregations.serialize(aggregationLabels),
    aggregationsIncludingComponent: aggregations.serialize(aggregationLabels + ignoredComponentJoinLabels),
    ignoreCondition: ignoreCondition(ignoreComponents),
  };

local apdexRatio(aggregationSet, range, groupSelectors, aggregationLabels, ignoreComponents) =
  |||
    clamp_max(
      sum by (%(aggregations)s)(
        sum by (%(aggregationsIncludingComponent)s) (
          sum_over_time(
            %(apdexSuccess)s{%(selectorHash)s}[%(range)s]
          )
        ) %(ignoreCondition)s
      )
      /
      sum by (%(aggregations)s)(
        sum by (%(aggregationsIncludingComponent)s) (
          sum_over_time(
            %(apdexWeight)s{%(selectorHash)s}[%(range)s]
          )
        ) %(ignoreCondition)s
      ),
    1)
  ||| % {
    apdexSuccess: aggregationSet.getApdexSuccessRateMetricForBurnRate('1h'),
    apdexWeight: aggregationSet.getApdexWeightMetricForBurnRate('1h'),
    selectorHash: selectors.serializeHash(groupSelectors),
    range: range,
    aggregations: aggregations.serialize(aggregationLabels),
    aggregationsIncludingComponent: aggregations.serialize(aggregationLabels + ignoredComponentJoinLabels),
    ignoreCondition: ignoreCondition(ignoreComponents),
  };

local errorRatio(aggregationSet, range, groupSelectors, aggregationLabels, ignoreComponents) =
  |||
    clamp_max(
      sum by (%(aggregations)s)(
        sum by (%(aggregationsIncludingComponent)s) (
          sum_over_time(
            %(errorRate)s{%(selectorHash)s}[%(range)s]
          )
        ) %(ignoreCondition)s
      )
      /
      sum by (%(aggregations)s)(
        sum by (%(aggregationsIncludingComponent)s) (
          sum_over_time(
            %(opsRate)s{%(selectorHash)s}[%(range)s]
          )
        ) %(ignoreCondition)s
      ),
    1)
  ||| % {
    errorRate: aggregationSet.getErrorRateMetricForBurnRate('1h'),
    opsRate: aggregationSet.getOpsRateMetricForBurnRate('1h'),
    selectorHash: selectors.serializeHash(groupSelectors),
    range: range,
    aggregations: aggregations.serialize(aggregationLabels),
    aggregationsIncludingComponent: aggregations.serialize(aggregationLabels + ignoredComponentJoinLabels),
    ignoreCondition: ignoreCondition(ignoreComponents),
  };


{
  build(aggregationSet, range): {
    combinedRatio(selectors, aggregationLabels=[], ignoreComponents=true):
      combinedRatio(aggregationSet, range, selectors, aggregationLabels, ignoreComponents),
    apdexRatio(selectors, aggregationLabels=[], ignoreComponents=true):
      apdexRatio(aggregationSet, range, selectors, aggregationLabels, ignoreComponents),
    errorRatio(selectors, aggregationLabels=[], ignoreComponents=true):
      errorRatio(aggregationSet, range, selectors, aggregationLabels, ignoreComponents),
  },
}
