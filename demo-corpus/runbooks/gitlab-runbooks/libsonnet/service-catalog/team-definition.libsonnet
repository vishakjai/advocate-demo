local metricsConfig = import 'gitlab-metrics-config.libsonnet';
local allServices = metricsConfig.monitoredServices;
local miscUtils = import 'utils/misc.libsonnet';
local validator = import 'utils/validator.libsonnet';

local serviceComponents = std.set(
  std.flatMap(
    function(o) std.objectFields(o.serviceLevelIndicators),
    allServices
  )
);

local ignoredComponentsValidator = validator.validator(
  function(teamIgnoredComponents)
    std.prune(teamIgnoredComponents) == null ||
    miscUtils.all(
      function(value) std.member(serviceComponents, value),
      teamIgnoredComponents
    ),
  'only components %s are supported' % [std.join(', ', serviceComponents)]
);

local productStageGroupValidator = validator.validator(
  function(stageGroup)
    std.prune(stageGroup) == null || std.objectHas(metricsConfig.stageGroupMapping, stageGroup),
  'unknown stage group'
);

// For basic type validations, use JSON Schema in https://gitlab.com/gitlab-com/runbooks/-/blob/master/services/service-catalog-schema.json
local teamValidator = validator.new({
  ignored_components: ignoredComponentsValidator,
  product_stage_group: productStageGroupValidator,
});

local teamDefaults = {
  issue_tracker: null,
  send_slo_alerts_to_team_slack_channel: false,
  ignored_components: [],
  product_stage_group: null,
};

{
  defaults: teamDefaults,

  // only for tests
  _validator: teamValidator,
  _serviceComponents: serviceComponents,
}
