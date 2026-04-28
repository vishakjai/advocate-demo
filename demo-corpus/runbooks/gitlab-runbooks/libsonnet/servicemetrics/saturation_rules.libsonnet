local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local objects = import 'utils/objects.libsonnet';

local assertEvaluationType(evaluation) =
  local knownTypes = ['prometheus', 'thanos', 'both'];
  assert std.member(knownTypes, evaluation) : 'Evaluation type %s is needs to be one of %s' % [evaluation, knownTypes];
  evaluation;

local getSelectorHash(evaluation) =
  if evaluation == 'thanos' then
    { monitor: 'global' }
  else
    {};

local filterSaturationDefinitions(
  saturationResources,
  evaluation,
  thanosSelfMonitoring
      ) =
  local saturationResourceNames = std.objectFields(saturationResources);
  std.filter(
    function(key)
      local definition = saturationResources[key];
      // Not all saturation metrics will match all architectures, filter our non-matches
      (std.length(definition.appliesTo) > 0)
      &&
      definition.hasServicesForResource(evaluation, thanosSelfMonitoring),
    saturationResourceNames
  );

local prepareGroups(
  groups,
  evaluation,
      ) =
  // When generating thanos-only rules, we need to add partial_response_strategy
  local groupBase =
    if evaluation == 'thanos' then
      { partial_response_strategy: 'warn' }
    else
      {};

  std.foldl(
    function(memo, group)
      local rules = std.prune(group.rules);
      if std.length(rules) == 0 then
        // Skip this group
        memo
      else
        memo + [groupBase + group {
          rules: rules,
        }],
    groups,
    []
  );

local generateSaturationAlertsGroup(
  saturationResources,
  evaluation,
  extraSelector={},
  thanosSelfMonitoring=false,  // Include Thanos self-monitor saturation rules in the alert groups
  tenant=null,
      ) =
  local knownEvaluation = assertEvaluationType(evaluation);
  local selectorHash = getSelectorHash(knownEvaluation) + extraSelector;
  local selector = selectors.serializeHash(selectorHash);

  local filtered = filterSaturationDefinitions(saturationResources, knownEvaluation, thanosSelfMonitoring);

  local saturationAlerts = std.flatMap(
    function(key)
      std.map(
        function(alert)
          objects.nestedMerge(alert, {
            annotations: {
              grafana_datasource_id: tenant,
            },
          }),
        saturationResources[key].getSaturationAlerts(key, selectorHash)
      ),
    filtered
  );

  prepareGroups([{
    name: 'GitLab Saturation Alerts',
    interval: '1m',
    rules: saturationAlerts,
  }], knownEvaluation);

local generateSaturationAuxRulesGroup(
  saturationResources,
  evaluation,
  extraSelector={},
  thanosSelfMonitoring=false,  // Include Thanos self-monitor saturation rules in the alert groups
  tenant=null,
      ) =
  local knownEvaluation = assertEvaluationType(evaluation);
  local selectorHash = getSelectorHash(knownEvaluation) + extraSelector;
  local selector = selectors.serializeHash(selectorHash);

  local filtered = filterSaturationDefinitions(saturationResources, knownEvaluation, thanosSelfMonitoring);

  local recordedQuantiles = (import 'servicemetrics/resource_saturation_point.libsonnet').recordedQuantiles;

  prepareGroups([{
    // Alerts for saturation metrics being out of threshold
    name: 'GitLab Component Saturation Statistics',
    interval: '5m',
    rules:
      [
        {
          record: 'gitlab_component_saturation:ratio_quantile%(quantile_percent)d_1w' % {
            quantile_percent: quantile * 100,
          },
          expr: 'quantile_over_time(%(quantile)g, gitlab_component_saturation:ratio{%(selector)s}[1w])' % {
            selector: selector,
            quantile: quantile,
          },
        }
        for quantile in recordedQuantiles
      ]
      +
      [
        {
          record: 'gitlab_component_saturation:ratio_quantile%(quantile_percent)d_1h' % {
            quantile_percent: quantile * 100,
          },
          expr: 'quantile_over_time(%(quantile)g, gitlab_component_saturation:ratio{%(selector)s}[1h])' % {
            selector: selector,
            quantile: quantile,
          },
        }
        for quantile in recordedQuantiles
      ]
      +
      [
        {
          record: 'gitlab_component_saturation:ratio_avg_1h',
          expr: 'avg_over_time(gitlab_component_saturation:ratio{%(selector)s}[1h])' % {
            selector: selector,
          },
        },
      ],
  }], knownEvaluation)
  + generateSaturationAlertsGroup(
    saturationResources,
    knownEvaluation,
    extraSelector,
    thanosSelfMonitoring,
    tenant
  );

local generateSaturationMetadataRulesGroup(
  saturationResources,
  evaluation,
  thanosSelfMonitoring=false,
  ignoreMetadata=false,  // flag to ignore the saturation metadata, in use by mimir impl. The thanos and prometheus impl. do not ignore them.
      ) =
  local knownEvaluation = assertEvaluationType(evaluation);
  local filtered = filterSaturationDefinitions(saturationResources, knownEvaluation, thanosSelfMonitoring);
  local sloThresholdRecordingRules = std.flatMap(function(key) saturationResources[key].getSLORecordingRuleDefinition(key), filtered);
  local saturationMetadataRecordingRules = std.map(function(key) saturationResources[key].getMetadataRecordingRuleDefinition(key), filtered);

  local maxSLOs = {
    // Recording rules defining the soft and hard SLO thresholds
    name: 'GitLab Component Saturation Max SLOs',
    interval: '5m',
    rules: sloThresholdRecordingRules,
  };
  // Drop this when migration to mimir is complete: https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2834
  local metadata =
    if ignoreMetadata
    then null
    else {
      // Metadata each of the saturation metrics
      name: 'GitLab Component Saturation Metadata',
      interval: '5m',
      rules: saturationMetadataRecordingRules,
    };

  prepareGroups(std.prune([maxSLOs, metadata]), knownEvaluation);

local generateSaturationRulesGroup(
  evaluation,  // 'prometheus', 'thanos' or 'both'
  saturationResources,
  extraSourceSelector={},
  thanosSelfMonitoring=false,
  staticLabels={},
      ) =
  local knownEvaluation = assertEvaluationType(evaluation);
  local selectorHash = getSelectorHash(knownEvaluation);

  local saturationResourceNames = std.objectFields(saturationResources);
  local filtered = filterSaturationDefinitions(saturationResources, knownEvaluation, thanosSelfMonitoring);

  local resourceAutoscalingRuleFiltered = std.filter(
    function(key) std.get(saturationResources[key], 'resourceAutoscalingRule', false),
    filtered
  );

  local rules = std.map(
    function(key)
      saturationResources[key].getRecordingRuleDefinition(
        key,
        knownEvaluation,
        thanosSelfMonitoring=thanosSelfMonitoring,
        staticLabels=staticLabels,
        extraSelector=extraSourceSelector,
      ),
    filtered
  );

  local resourceAutoscalingRules = std.map(
    function(key)
      saturationResources[key].getResourceAutoscalingRecordingRuleDefinition(
        key,
        knownEvaluation,
        thanosSelfMonitoring=thanosSelfMonitoring,
        staticLabels=staticLabels,
        extraSelector=extraSourceSelector
      ),
    resourceAutoscalingRuleFiltered
  );

  local namePrefix = if thanosSelfMonitoring then 'Thanos Self-Monitoring ' else '';

  prepareGroups([{
    // Recording rules for each saturation metric
    name: namePrefix + 'Saturation Rules (autogenerated)',
    interval: '1m',
    rules: rules,
  }, {
    // Recording rules for each resource saturation metric for autoscaling
    name: namePrefix + 'Resource Saturation Rules (autogenerated)',
    interval: '1m',
    rules: resourceAutoscalingRules,
  }], knownEvaluation);

{
  generateSaturationRulesGroup:: generateSaturationRulesGroup,
  generateSaturationAuxRulesGroup:: generateSaturationAuxRulesGroup,
  generateSaturationAlertsGroup:: generateSaturationAlertsGroup,
  generateSaturationMetadataRulesGroup:: generateSaturationMetadataRulesGroup,
}
