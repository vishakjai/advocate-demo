local errorBudget = import '../libsonnet/stage-groups/error_budget.libsonnet';
local periodicQuery = import './periodic-query.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local datetime = import 'utils/datetime.libsonnet';

local selector = {
  environment: 'gprd',
  monitor: 'global',
};

local now = std.extVar('current_time');
local midnight = datetime.new(now).beginningOfDay.toString;
local range = '7d';
local queries = errorBudget(range).queries;

local completenessIndicatorQuery = |||
  1
  -
  (
    sum(
      sum_over_time(gitlab:component:feature_category:execution:ops:rate_1h{%(selector)s, feature_category=~"not_owned|unknown"}[%(range)s])
    )
    +
    sum(
      sum_over_time(gitlab:component:feature_category:execution:ops:rate_1h{%(selector)s, feature_category!~"not_owned|unknown"}[%(range)s])
      and on (component) gitlab:ignored_component:stage_group
    )
  )
  /
  (
    sum(
      sum_over_time(gitlab:component:feature_category:execution:ops:rate_1h{%(selector)s}[%(range)s])
    )
  )
||| % {
  selector: selectors.serializeHash(selector),
  range: range,
};

{
  stage_group_error_budget_completeness: periodicQuery.new({
    requestParams: {
      query: completenessIndicatorQuery,
      time: midnight,
    },
  }),
  stage_group_error_budget_teams_over_budget_availability: periodicQuery.new({
    requestParams: {
      query: queries.errorBudgetGroupsOverBudget(selector),
      time: midnight,
    },
  }),
}
