local periodicQuery = import './periodic-query.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local datetime = import 'utils/datetime.libsonnet';

local selector = {
  env: 'gprd',
};
local aggregationLabels = ['stage_group', 'product_stage', 'user_experience_id'];
local now = std.extVar('current_time');
local midnight = datetime.new(now).beginningOfDay.toString;

local userExperienceSliMonthlyAvailability = function(range='28d')
  local ratioQuery = |||
    max by (%(aggregations)s) (
      last_over_time(gitlab:user_experience_sli:stage_groups:availability:ratio_%(range)s{%(selector)s}[2h])
    )
  ||| % {
    selector: selectors.serializeHash(selector),
    range: range,
    aggregations: aggregations.join(aggregationLabels),
  };

  {
    user_experience_sli_error_budget_availability: periodicQuery.new({
      requestParams: {
        query: ratioQuery,
        time: midnight,
      },
    }),
  };

{
  userExperienceSliMonthlyAvailability: userExperienceSliMonthlyAvailability,
}
