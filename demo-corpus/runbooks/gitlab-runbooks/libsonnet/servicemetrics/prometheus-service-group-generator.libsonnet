local intervalForDuration = import './interval-for-duration.libsonnet';
local recordingRules = import 'recording-rules/recording-rules.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

local recordingRuleGroupsForServiceForBurnRate(serviceDefinition, componentAggregationSet, nodeAggregationSet, shardAggregationSet, burnRate, config) =
  local rulesetGenerators =
    [
      recordingRules.sliRecordingRulesSetGenerator(burnRate, config.recordingRuleRegistry),
      recordingRules.componentMetricsRuleSetGenerator(
        burnRate=burnRate,
        aggregationSet=componentAggregationSet,
        config=config
      ),
    ]
    +
    (
      if serviceDefinition.monitoring.node.enabled then
        [
          recordingRules.componentMetricsRuleSetGenerator(
            burnRate=burnRate,
            aggregationSet=nodeAggregationSet,
            config=config
          ),
        ]
      else
        []
    );

  local shardLevelIndicators = std.filter(function(indicator) indicator.shardLevelMonitoring, serviceDefinition.listServiceLevelIndicators());
  local shardLevelIndicatorsRules = recordingRules.componentMetricsRuleSetGenerator(
    burnRate=burnRate,
    aggregationSet=shardAggregationSet,
    config=config,
  );

  {
    name: 'Component-Level SLIs: %s - %s burn-rate' % [serviceDefinition.type, burnRate],  // TODO: rename to "Prometheus Intermediate Metrics"
    interval: intervalForDuration.intervalForDuration(burnRate),
    rules:
      std.flatMap(
        function(r) r.generateRecordingRulesForService(serviceDefinition),
        rulesetGenerators
      ) + if std.length(shardLevelIndicators) > 0 then
        shardLevelIndicatorsRules.generateRecordingRulesForService(serviceDefinition, shardLevelIndicators)
      else
        [],
  };

local featureCategoryRecordingRuleGroupsForService(serviceDefinition, aggregationSet, burnRate, config) =
  local generator = recordingRules.componentMetricsRuleSetGenerator(burnRate, aggregationSet, config=config);
  local indicators = std.filter(function(indicator) indicator.hasFeatureCategory(), serviceDefinition.listServiceLevelIndicators());
  {
    name: 'Prometheus Intermediate Metrics per feature: %s - burn-rate %s' % [serviceDefinition.type, burnRate],
    interval: intervalForDuration.intervalForDuration(burnRate),
    rules: generator.generateRecordingRulesForService(serviceDefinition, serviceLevelIndicators=indicators),
  };

{

  config: import 'gitlab-metrics-config.libsonnet',
  /**
   * Generate all source recording rule groups for a specific service.
   * These are the first level aggregation, for normalizing source metrics
   * into a consistent format
   */
  recordingRuleGroupsForService(serviceDefinition, componentAggregationSet, nodeAggregationSet=null, shardAggregationSet=null)::
    local componentMappingRuleSetGenerator = recordingRules.componentMappingRuleSetGenerator();

    local burnRates = componentAggregationSet.getBurnRates();

    [
      recordingRuleGroupsForServiceForBurnRate(serviceDefinition, componentAggregationSet, nodeAggregationSet, shardAggregationSet, burnRate, self.config)
      for burnRate in burnRates
    ]
    +
    // Component mappings are static recording rules which help
    // determine whether a component is being monitored. This helps
    // prevent spurious alerts when a component is decommissioned.
    [{
      name: 'Component mapping: %s' % [serviceDefinition.type],
      interval: '1m',  // TODO: we could probably extend this out to 5m
      rules:
        componentMappingRuleSetGenerator.generateRecordingRulesForService(serviceDefinition),
    }],

  featureCategoryRecordingRuleGroupsForService(serviceDefinition, aggregationSet)::
    [
      featureCategoryRecordingRuleGroupsForService(serviceDefinition, aggregationSet, burnRate, self.config)
      for burnRate in aggregationSet.getBurnRates()
    ],

}
