local queryBuilder = import '../error-budget/query-builder.libsonnet';
local gitlabMetricsConfig = import 'gitlab-metrics-config.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local aggregationSet = gitlabMetricsConfig.aggregationSets.userExperienceSliStageGroups;

local opsRate(range, selectorLabels, aggregationLabels, burnRate) =
  |||
    sum by (%(aggregations)s)(
      sum_over_time(%(metric)s{%(selector)s}[%(range)s])
    )
  ||| % {
    metric: aggregationSet.getOpsRateMetricForBurnRate(burnRate),
    selector: selectors.serializeHash(selectorLabels),
    range: range,
    aggregations: aggregations.serialize(aggregationLabels),
  };

{
  init(range): {
    local defaultBurnRate = '1h',
    local queries = queryBuilder.build(aggregationSet, range),

    combinedRatio: queries.combinedRatio,
    apdexRatio: queries.apdexRatio,
    errorRatio: queries.errorRatio,

    opsRate(selectorLabels, aggregationLabels=[], burnRate=defaultBurnRate):
      opsRate(range, selectorLabels, aggregationLabels, burnRate),
  },
}
