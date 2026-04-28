local recordingRules = import 'recording-rules/recording-rules.libsonnet';
local intervalForDuration = import 'servicemetrics/interval-for-duration.libsonnet';

local generateRecordingRules(sourceAggregationSet, targetAggregationSet, burnRates) =
  std.flatMap(
    function(burnRate)
      // Operation rate and Error Rate
      recordingRules.aggregationSetRateRuleSet(sourceAggregationSet=sourceAggregationSet, targetAggregationSet=targetAggregationSet, burnRate=burnRate)
      +
      // Error Ratio
      recordingRules.aggregationSetErrorRatioRuleSet(sourceAggregationSet=sourceAggregationSet, targetAggregationSet=targetAggregationSet, burnRate=burnRate)
      +
      // Apdex Score and Apdex Weight and Apdex SuccessRate
      recordingRules.aggregationSetApdexRatioRuleSet(sourceAggregationSet=sourceAggregationSet, targetAggregationSet=targetAggregationSet, burnRate=burnRate)
      +
      recordingRules.aggregationSetTransactionalRatesRuleSet(sourceAggregationSet=sourceAggregationSet, targetAggregationSet=targetAggregationSet, burnRate=burnRate),
    burnRates
  );

local groupForSetAndType(aggregationSet, burnType, emittingType) =
  {
    name: '%s (%s burn)%s' % [aggregationSet.name, burnType, if emittingType != null then ' emitted by %s' % emittingType else ''],
    interval: intervalForDuration.intervalByBurnType[burnType],
  };

local generateRecordingRuleGroups(sourceAggregationSet, targetAggregationSet, extrasForGroup={}, emittingType=null) =
  local burnRatesByType = targetAggregationSet.getBurnRatesByType();
  std.map(
    function(burnType)
      groupForSetAndType(targetAggregationSet, burnType, emittingType) {
        rules: generateRecordingRules(sourceAggregationSet, targetAggregationSet, burnRatesByType[burnType]),
      } + extrasForGroup,
    std.objectFields(burnRatesByType)
  );

{
  /**
   * Generates a set of recording rules to aggregate from a source aggregation set to a target aggregation set
   */
  generateRecordingRuleGroups:: generateRecordingRuleGroups,
}
