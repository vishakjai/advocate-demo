local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';
local validator = import 'utils/validator.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local successCounterApdex = metricsCatalog.successCounterApdex;
local serviceLevelIndicatorDefinition = import 'servicemetrics/service_level_indicator_definition.libsonnet';
local misc = import 'utils/misc.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';


// When adding new kinds, please update the metrics catalog to add recording
// names to the aggregation sets and recording rules
local apdexKind = 'apdex';
local errorRateKind = 'error_rate';
local validKinds = [apdexKind, errorRateKind];

local validKindsValidator = validator.validator(function(values) misc.all(function(v) std.member(validKinds, v), values), 'only %s are supported' % [std.join(', ', validKinds)]);
local validateFeatureCategory(value) =
  if value == serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics then
    true
  else if value != null then
    std.objectHas(stages.featureCategoryMap, value)
  else
    false;

local sliValidator = validator.new({
  name: validator.string,
  counterName: validator.string,
  significantLabels: validator.array,
  description: validator.string,
  kinds: validator.and(
    validator.validator(function(values) std.isArray(values) && std.length(values) > 0, 'must be present'),
    validKindsValidator
  ),
  featureCategory: validator.validator(validateFeatureCategory, 'please specify a known feature category or include `feature_category` as a significant label'),
  dashboardFeatureCategories: validator.validator(
    function(values) misc.all(function(v) std.objectHas(stages.featureCategoryMap, v), values),
    'contains unknown feature categories'
  ),
});

local rateQueryFunction(sli, counter) =
  function(selector={}, aggregationLabels=[], rangeInterval)
    local labels = std.set(aggregationLabels + sli.significantLabels);
    rateMetric(sli[counter], selector) { config+: sli.config }.aggregatedRateQuery(labels, selector, rangeInterval);

local applyDefaults(definition) = {
  config:: recordingRuleRegistry.defaultConfig,
  featureCategory: if std.member(definition.significantLabels, 'feature_category') then
    serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics,
  hasApdex():: std.member(definition.kinds, apdexKind),
  hasErrorRate():: std.member(definition.kinds, errorRateKind),
  dashboardFeatureCategories: [],
  counterName: if std.get(definition, 'counterName') == null then definition.name else definition.counterName,
} + definition;

local validateDashboardFeatureCategories(definition) =
  if std.length(definition.dashboardFeatureCategories) > 0 &&
     definition.featureCategory != serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics then
    std.assertEqual(definition.dashboardFeatureCategories,
                    { __assert__: 'dashboardFeatureCategories can only be set when feature categories come from source metrics' })
  else
    definition;

local validateAndApplyDefaults(definition) =
  local definitionWithDefaults = applyDefaults(definition);
  local sli = validateDashboardFeatureCategories(sliValidator.assertValid(definitionWithDefaults));

  sli {
    [if sli.hasApdex() then 'apdexTotalCounterName']: 'gitlab_sli_%s_apdex_total' % [self.counterName],
    [if sli.hasApdex() then 'apdexSuccessCounterName']: 'gitlab_sli_%s_apdex_success_total' % [self.counterName],
    [if sli.hasErrorRate() then 'errorTotalCounterName']: 'gitlab_sli_%s_total' % [self.counterName],
    [if sli.hasErrorRate() then 'errorCounterName']: 'gitlab_sli_%s_error_total' % [self.counterName],
    totalCounterName:
      if sli.hasErrorRate() then
        self.errorTotalCounterName
      else
        self.apdexTotalCounterName,
    [if sli.hasApdex() then 'aggregatedApdexOperationRateQuery']:: rateQueryFunction(self, 'apdexTotalCounterName'),
    [if sli.hasApdex() then 'aggregatedApdexSuccessRateQuery']:: rateQueryFunction(self, 'apdexSuccessCounterName'),
    [if sli.hasErrorRate() then 'aggregatedOperationRateQuery']:: rateQueryFunction(self, 'errorTotalCounterName'),
    [if sli.hasErrorRate() then 'aggregatedErrorRateQuery']:: rateQueryFunction(self, 'errorCounterName'),

    recordingRuleMetrics: std.filter(misc.isPresent, [
      misc.dig(self, ['apdexTotalCounterName']),
      misc.dig(self, ['apdexSuccessCounterName']),
      misc.dig(self, ['errorTotalCounterName']),
      misc.dig(self, ['errorCounterName']),
    ]),

    inRecordingRuleRegistry(registry=self.config.recordingRuleRegistry): misc.all(
      function(metricName)
        registry.resolveRecordingRuleFor(metricName=metricName) != null,
      self.recordingRuleMetrics,
    ),

    recordingRuleStaticLabels:
      if std.objectHas(sli, 'featureCategory') && sli.featureCategory != serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics
      then { feature_category: sli.featureCategory }
      else {},

    local parent = self,

    generateServiceLevelIndicator(extraSelector, extraFields={}):: {
      [sli.name]: {
        userImpacting: true,
        featureCategory: sli.featureCategory,

        dashboardFeatureCategories: parent.dashboardFeatureCategories,
        description: parent.description,

        requestRate: rateMetric(parent.totalCounterName, extraSelector),
        significantLabels: parent.significantLabels,

        [if parent.hasApdex() then 'apdex']:
          successCounterApdex(parent.apdexSuccessCounterName, parent.apdexTotalCounterName, extraSelector),
        [if parent.hasErrorRate() then 'errorRate']:
          rateMetric(parent.errorCounterName, extraSelector),
      } + extraFields,
    },
  };

{
  apdexKind: apdexKind,
  errorRateKind: errorRateKind,

  new(definition):: validateAndApplyDefaults(definition),

  // For testing only
  _sliValidator:: sliValidator,
  _applyDefaults:: applyDefaults,
}
