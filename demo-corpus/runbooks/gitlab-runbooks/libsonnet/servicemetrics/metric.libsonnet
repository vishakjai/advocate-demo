local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';
local validator = import 'utils/validator.libsonnet';

local metricValidator = validator.new({
  selector: validator.object,
});

local config = {
  config:: recordingRuleRegistry.defaultConfig,
};

{
  new(metric):: config + metricValidator.assertValid(metric),
}
