local aggregations = import 'promql/aggregations.libsonnet';
local errorBudget = import 'stage-groups/error_budget.libsonnet';
local strings = import 'utils/strings.libsonnet';

local ruleGroup(groupExtras) = {
  // Using a long interval, because aggregating 28d worth of data is not cheap,
  // but it also doesn't change fast.
  // Make sure to query these with `last_over_time([ > 30m])`
  interval: '30m',
} + groupExtras;

local groupLabels = ['stage_group', 'product_stage'];
local environmentLabels = ['environment'];
local aggregationLabels = groupLabels + environmentLabels;
local selector = {
  // Filtering out staging and canary makes these queries a tiny bit cheaper
  // Aggregating seemed to cause timeouts
  stage: 'main',
  environment: 'gprd',
  monitor: 'global',
};
local budget = errorBudget();
local thanosCompatibilityLabels = {
  monitor: 'global',
};

local rules(groupExtras={}) = {
  groups: [
    ruleGroup(groupExtras) {
      name: '%s availability by stage group' % [range],
      rules: [{
        record: 'gitlab:stage_group:availability:ratio_%s' % [range],
        labels: thanosCompatibilityLabels,
        expr: errorBudget(range).queries.errorBudgetRatio(selector, aggregationLabels),
      }],
    }
    for range in ['7d', '28d']
  ] + [
    ruleGroup(groupExtras) {
      name: '28d availability by stage group and SLI kind',
      rules: [{
        record: 'gitlab:stage_group:sli_kind:availability:ratio_28d',
        labels: thanosCompatibilityLabels,
        expr: budget.queries.errorBudgetRatio(selector, aggregationLabels + ['sli_kind']),
      }],
    },
    ruleGroup(groupExtras) {
      name: '28d traffic share per stage group',
      rules: [{
        record: 'gitlab:stage_group:traffic_share:ratio_28d',
        labels: thanosCompatibilityLabels,
        expr: |||
          (
            %(operationRateByStageGroup)s
          )
          / ignoring(%(groupLabels)s) group_left()
          (
            %(operationRateByEnvironment)s
          )
        ||| % {
          operationRateByStageGroup:
            strings.indent(strings.chomp(budget.queries.errorBudgetOperationRate(selector, aggregationLabels)), 2),
          operationRateByEnvironment:
            strings.indent(strings.chomp(budget.queries.errorBudgetOperationRate(selector, environmentLabels)), 2),
          groupLabels: aggregations.serialize(groupLabels),
        },
      }],
    },
  ],
};

rules
