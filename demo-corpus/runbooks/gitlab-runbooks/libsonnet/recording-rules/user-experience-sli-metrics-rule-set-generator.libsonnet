local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local generateUserExperienceSliRules(burnRate, aggregationSet, extraSelector) =
  local baseSelector = selectors.merge(
    aggregationSet.selector,
    extraSelector
  );

  [
    {
      record: aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=true),
      expr: aggregations.aggregateOverQuery(
        'sum',
        aggregationSet.labels,
        'rate(gitlab_user_experience_total{%(selector)s}[%(burnRate)s])' % {
          selector: selectors.serializeHash(baseSelector),
          burnRate: burnRate,
        }
      ),
    },
    {
      record: aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate, required=true),
      expr: aggregations.aggregateOverQuery(
        'sum',
        aggregationSet.labels,
        'rate(gitlab_user_experience_apdex_total{%(selector)s}[%(burnRate)s])' % {
          selector: selectors.serializeHash(baseSelector { success: true }),
          burnRate: burnRate,
        }
      ),
    },
    {
      record: aggregationSet.getApdexWeightMetricForBurnRate(burnRate, required=true),
      expr: aggregations.aggregateOverQuery(
        'sum',
        aggregationSet.labels,
        'rate(gitlab_user_experience_apdex_total{%(selector)s}[%(burnRate)s])' % {
          selector: selectors.serializeHash(baseSelector),
          burnRate: burnRate,
        }
      ),
    },
  ] +
  // Generate ratio rules using the aggregation set's built-in ratio generators
  (
    if aggregationSet.getApdexRatioMetricForBurnRate(burnRate, required=false) != null
    then
      [{
        record: aggregationSet.getApdexRatioMetricForBurnRate(burnRate, required=true),
        expr: |||
          %(numerator)s{%(selector)s}
          /
          %(denominator)s{%(selector)s}
        ||| % {
          numerator: aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate, required=true),
          denominator: aggregationSet.getApdexWeightMetricForBurnRate(burnRate, required=true),
          selector: selectors.serializeHash(baseSelector),
        },
      }]
    else
      []
  ) +
  (
    if aggregationSet.getErrorRateMetricForBurnRate(burnRate, required=false) != null
    then
      [{
        record: aggregationSet.getErrorRateMetricForBurnRate(burnRate, required=true),
        expr: aggregations.aggregateOverQuery(
          'sum',
          aggregationSet.labels,
          'rate(gitlab_user_experience_total{%(selector)s}[%(burnRate)s])' % {
            selector: selectors.serializeHash(baseSelector { 'error': true }),
            burnRate: burnRate,
          }
        ),
      }]
    else
      []
  ) +
  (
    if aggregationSet.getErrorRatioMetricForBurnRate(burnRate, required=false) != null
    then
      [{
        record: aggregationSet.getErrorRatioMetricForBurnRate(burnRate, required=true),
        expr: |||
          %(numerator)s{%(selector)s}
          /
          %(denominator)s{%(selector)s}
        ||| % {
          numerator: aggregationSet.getErrorRateMetricForBurnRate(burnRate, required=true),
          denominator: aggregationSet.getOpsRateMetricForBurnRate(burnRate, required=true),
          selector: selectors.serializeHash(baseSelector),
        },
      }]
    else
      []
  );

{
  // This user experience SLI metrics ruleset generates recording rules for
  // user experience SLI metrics aggregations
  userExperienceSliMetricsRuleSetGenerator(
    burnRate,
    aggregationSet,
    extraSourceSelector={},
    config={},
  ): {
    config: config,

    // List of services for user experience SLI metrics
    // TODO: https://gitlab.com/gitlab-com/gl-infra/observability/team/-/issues/4381
    // This filter can be removed after this limit issue is solved.
    local allowedServiceTypes = [
      'ai-assisted',
      'api',
      'git',
      'internal-api',
      'sidekiq',
      'web',
      'websockets',
    ],

    // Generates the recording rules for services that emit user experience SLI metrics
    generateRecordingRulesForService(
      serviceDefinition,
      serviceLevelIndicators=[],  // Not used for user experience SLI aggregations
    ):
      if std.member(allowedServiceTypes, serviceDefinition.type) then
        local serviceSelector = selectors.merge(
          { type: serviceDefinition.type },
          extraSourceSelector
        );

        generateUserExperienceSliRules(burnRate, aggregationSet, serviceSelector)
      else
        [],
  },
}
