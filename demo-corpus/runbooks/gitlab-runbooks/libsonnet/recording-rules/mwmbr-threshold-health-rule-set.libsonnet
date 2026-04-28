local mwmbrExpression = import 'mwmbr/expression.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local selectors = import 'promql/selectors.libsonnet';

local otherThresholdRules(threshold, selector) =
  [{
    record: threshold.errorHealth,
    expr: mwmbrExpression.errorHealthExpression(
      aggregationSet=aggregationSets.serviceSLIs,
      metricSelectorHash=selector,
      thresholdSLOMetricName=threshold.errorSLO,
      thresholdSLOMetricAggregationLabels=['type', 'tier'],
    ),
  }, {
    record: threshold.apdexHealth,
    expr: mwmbrExpression.apdexHealthExpression(
      aggregationSet=aggregationSets.serviceSLIs,
      metricSelectorHash=selector,
      thresholdSLOMetricName=threshold.apdexSLO,
      thresholdSLOMetricAggregationLabels=['type', 'tier'],
    ),
  }, {
    record: threshold.aggregateServiceHealth,
    expr: |||
      min without (sli_type) (
        label_replace(%(apdexHealth)s{%(selector)s}, "sli_type", "apdex", "", "")
        or
        label_replace(%(errorHealth)s{%(selector)s}, "sli_type", "errors", "", "")
      )
    ||| % {
      apdexHealth: threshold.apdexHealth,
      errorHealth: threshold.errorHealth,
      selector: selectors.serializeHash({ monitor: 'global' } + selector),
    },
  }, {
    record: threshold.aggregateStageHealth,
    expr: |||
      min by (environment, env, stage) (
        %(aggregateServiceHealth)s{%(selector)s}
      )
    ||| % {
      aggregateServiceHealth: threshold.aggregateServiceHealth,
      selector: selectors.serializeHash({ monitor: 'global' } + selector),
    },
  }];

{
  thresholdHealthRuleSet:: otherThresholdRules,
}
