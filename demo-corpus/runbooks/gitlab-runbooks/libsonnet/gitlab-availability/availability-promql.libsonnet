local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local misc = import 'utils/misc.libsonnet';
local strings = import 'utils/strings.libsonnet';

{
  new(keyServices, aggregationSet, extraSelector={}):: {
    local burnRate = '1h',  // use the one hour burn rate as the largest non-upscaled one

    local selector = if keyServices == '*' then
      extraSelector
    else
      extraSelector { type: { oneOf: keyServices } },


    local formatConfig = {
      aggregationLabels: aggregations.serialize(aggregationSet.labels),
      selector: selectors.serializeHash(selector),
      apdexSuccessRate: aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate, required=true),
      errorRate: aggregationSet.getErrorRateMetricForBurnRate(burnRate, required=true),
      apdexWeight: aggregationSet.getApdexWeightMetricForBurnRate(burnRate, required=true),
      opsRate: aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=true),
    },

    local successRate = |||
      (
        sum by(%(aggregationLabels)s) (
          %(apdexSuccessRate)s{%(selector)s}
        )
        +
        sum by (%(aggregationLabels)s)(
          %(opsRate)s{%(selector)s} - %(errorRate)s{%(selector)s}
        )
      )
    ||| % formatConfig,

    local opsRate = |||
      (
        sum by(%(aggregationLabels)s) (
          %(opsRate)s{%(selector)s}
        )
        +
        sum by (%(aggregationLabels)s) (
          %(apdexWeight)s{%(selector)s}
        )
      )
    ||| % formatConfig,

    successRate: successRate,
    opsRate: opsRate,

    local availabilityOpsRate = 'gitlab:availability:ops:rate_%s' % [burnRate],
    local availabilitySuccessRate = 'gitlab:availability:success:rate_%s' % [burnRate],
    availabilityRatio(aggregationLabels, selector, range, services):
      local selectorIncludingServices = selector { type: { oneOf: services } };
      |||
        sum by (%(aggregationLabels)s) (
          sum_over_time(%(availabilitySuccessRate)s{%(selector)s}[%(range)s])
        )
        /
        sum by (%(aggregationLabels)s) (
          sum_over_time(%(availabilityOpsRate)s{%(selector)s}[%(range)s])
        )
      ||| % {
        aggregationLabels: aggregations.join(aggregationLabels),
        selector: selectors.serializeHash(selectorIncludingServices),
        range: range,
        availabilitySuccessRate: availabilitySuccessRate,
        availabilityOpsRate: availabilityOpsRate,
      },

    weightedAvailabilityQuery(serviceWeights, selector, range):
      local joinQueries = function(queries)
        std.join('\n  or\n  ', std.map(
          function(query)
            strings.indent(strings.chomp(query), 2),
          queries
        ));
      local weightedSumOfRates = function(rateQuery)
        local rateQueries = std.map(
          function(service)
            local selectorWithType = selector { type: service };
            |||
              sum by (type)(
                sum_over_time(%(rateQuery)s{%(selector)s}[%(range)s]) * %(serviceWeight)s
              )
            ||| % {
              serviceWeight: serviceWeights[service],
              rateQuery: rateQuery,
              selector: selectors.serializeHash(selectorWithType),
              range: range,
            }, std.objectFields(serviceWeights)
        );
        joinQueries(rateQueries);

      local numerator = weightedSumOfRates(availabilitySuccessRate);
      local denominator = weightedSumOfRates(availabilityOpsRate);
      |||
        sum(
          %(numerator)s
        )
        /
        sum(
          %(denominator)s
        )
      ||| % {
        numerator: numerator,
        denominator: denominator,
      },

    rateRules: [
      {
        record: availabilityOpsRate,
        expr: aggregations.aggregateOverQuery('sum', formatConfig.aggregationLabels, opsRate),
      },
      {
        record: availabilitySuccessRate,
        expr: aggregations.aggregateOverQuery('sum', formatConfig.aggregationLabels, successRate),
      },
    ],
  },
}
