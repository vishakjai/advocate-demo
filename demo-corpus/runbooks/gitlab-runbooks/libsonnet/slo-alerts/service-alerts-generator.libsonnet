local serviceLevelAlerts = import './service-level-alerts.libsonnet';
local sloAlertAnnotations = import './slo-alert-annotations.libsonnet';
local labelsForSLIAlert = import './slo-alert-labels.libsonnet';
local trafficCessationAlertForSLIForAlertDescriptor = import './traffic-cessation-alerts.libsonnet';
local alerts = import 'alerts/alerts.libsonnet';
local misc = import 'utils/misc.libsonnet';
local objects = import 'utils/objects.libsonnet';

// maps aggregationSet.id to corresponding field in service.monitoring (following misc.dig key path)
local aggregationSetToServiceMonitoringField = {
  component_node: ['node', 'thresholds'],
};

// thresholdField is either 'apdexScore' or 'errorRatio'
local getThresholdSLOValue(service, sli, alertDescriptor, thresholdField) =
  local monitoringObjField = std.get(aggregationSetToServiceMonitoringField, alertDescriptor.aggregationSet.id);
  local monitoringObjValue = if monitoringObjField != null then
    misc.dig(service.monitoring, monitoringObjField + [thresholdField])
  else
    {};

  if monitoringObjValue != {} then
    monitoringObjValue
  else
    std.get(sli.monitoringThresholds, thresholdField);

local shardLevelOverridesExists(service, sli) =
  sli.shardLevelMonitoring &&
  std.length(
    std.objectFields(
      std.get(
        service.getShardMonitoringOverrides(),
        sli.name,
        default={}
      )
    )
  ) > 0;

local generateShardSelectorsAndThreshold(service, sli, thresholdField) =
  local overridenShardsSelector = service.listOverridenShardsMonitoringThresholds(sli, thresholdField);

  if std.length(overridenShardsSelector) > 0 then
    local otherShardsSelector = [
      {
        shard: { noneOf: std.map(function(s) s.shard, overridenShardsSelector) },
        threshold: std.get(sli.monitoringThresholds, thresholdField),
      },
    ];
    otherShardsSelector + overridenShardsSelector
  else
    [];

local apdexAlertForSLIForAlertDescriptor(service, sli, alertDescriptor, extraSelector) =
  local formatConfig = {
    sliName: sli.name,
    serviceType: service.type,
  };

  local shardSelectors = if service.hasShardMonitoringOverrides(sli) then
    generateShardSelectorsAndThreshold(service, sli, 'apdexScore')
  else
    [];

  // We use confidence_levels when the SLI requests it
  // AND the aggregation set supports it too
  local apdexConfidenceIntervalsAvailable =
    if sli.usesConfidenceLevelForSLIAlerts() != null then
      if std.all([
        alertDescriptor.aggregationSet.getApdexRatioConfidenceIntervalMetricForBurnRate(window) != null
        for window in service.alertWindows
      ]) then
        sli.getConfidenceLevel()
      else
        std.trace('warning: SLI %s-%s wants to use confidence intervals for apdex, but its not supported on the %s aggregation set used for SLO alerting' % [service.type, sli.name, alertDescriptor.aggregationSet.id], null)
    else
      null;

  local confidenceAlertLabels = if apdexConfidenceIntervalsAvailable != null then { confidence: apdexConfidenceIntervalsAvailable } else {};

  local apdexAlerts = function(thresholdSLOValue, metricSelectorHash)
    serviceLevelAlerts.apdexAlertsForSLI(
      alertName=serviceLevelAlerts.nameSLOViolationAlert(service.type, sli.name, 'ApdexSLOViolation' + alertDescriptor.alertSuffix),
      alertTitle=(alertDescriptor.alertTitleTemplate + ' has an apdex violating SLO') % formatConfig,
      alertDescriptionLines=[sli.description] + if alertDescriptor.alertExtraDetail != null then [alertDescriptor.alertExtraDetail] else [],
      serviceType=service.type,
      severity=sli.severity,
      thresholdSLOValue=thresholdSLOValue,
      aggregationSet=alertDescriptor.aggregationSet,
      windows=service.alertWindows,
      metricSelectorHash=metricSelectorHash,
      minimumSamplesForMonitoring=alertDescriptor.minimumSamplesForMonitoring,
      minimumOpsRateForMonitoring=std.get(alertDescriptor, 'minimumOpsRateForMonitoring', null),
      confidenceIntervalLevel=apdexConfidenceIntervalsAvailable,
      alertForDuration=alertDescriptor.alertForDuration,
      extraLabels=labelsForSLIAlert(sli) + confidenceAlertLabels,
      extraAnnotations=sloAlertAnnotations(service.type, sli, alertDescriptor.aggregationSet, 'apdex')
    );

  if std.length(shardSelectors) > 0 then
    std.flatMap(
      function(shardSelector) apdexAlerts(
        shardSelector.threshold,
        { type: service.type, component: sli.name, shard: shardSelector.shard } + extraSelector
      ),
      shardSelectors
    )
  else
    local apdexScoreSLO = getThresholdSLOValue(service, sli, alertDescriptor, 'apdexScore');
    apdexAlerts(apdexScoreSLO, { type: service.type, component: sli.name } + extraSelector);


local errorAlertForSLIForAlertDescriptor(service, sli, alertDescriptor, extraSelector) =
  local formatConfig = {
    sliName: sli.name,
    serviceType: service.type,
  };

  local shardSelectors = if shardLevelOverridesExists(service, sli) then
    generateShardSelectorsAndThreshold(service, sli, 'errorRatio')
  else
    [];

  // We use confidence_levels when the SLI requests it
  // AND the aggregation set supports it too
  local errorConfidenceIntervalsAvailable =
    if sli.usesConfidenceLevelForSLIAlerts() != null then
      if std.all([
        alertDescriptor.aggregationSet.getErrorRatioConfidenceIntervalMetricForBurnRate(window) != null
        for window in service.alertWindows
      ]) then
        sli.getConfidenceLevel()
      else
        std.trace('warning: SLI %s-%s wants to use confidence intervals for errors, but its not supported on the %s aggregation set used for SLO alerting' % [service.type, sli.name, alertDescriptor.aggregationSet.id], null)
    else
      null;

  local confidenceAlertLabels = if errorConfidenceIntervalsAvailable != null then { confidence: errorConfidenceIntervalsAvailable } else {};

  local errorAlerts = function(thresholdSLOValue, metricSelectorHash)
    serviceLevelAlerts.errorAlertsForSLI(
      alertName=serviceLevelAlerts.nameSLOViolationAlert(service.type, sli.name, 'ErrorSLOViolation' + alertDescriptor.alertSuffix),
      alertTitle=(alertDescriptor.alertTitleTemplate + ' has an error rate violating SLO') % formatConfig,
      alertDescriptionLines=[sli.description] + if alertDescriptor.alertExtraDetail != null then [alertDescriptor.alertExtraDetail] else [],
      serviceType=service.type,
      severity=sli.severity,
      thresholdSLOValue=thresholdSLOValue,
      aggregationSet=alertDescriptor.aggregationSet,
      windows=service.alertWindows,
      metricSelectorHash=metricSelectorHash,
      minimumSamplesForMonitoring=alertDescriptor.minimumSamplesForMonitoring,
      minimumOpsRateForMonitoring=std.get(alertDescriptor, 'minimumOpsRateForMonitoring', null),
      confidenceIntervalLevel=errorConfidenceIntervalsAvailable,
      extraLabels=labelsForSLIAlert(sli) + confidenceAlertLabels,
      alertForDuration=alertDescriptor.alertForDuration,
      extraAnnotations=sloAlertAnnotations(service.type, sli, alertDescriptor.aggregationSet, 'error'),
    );

  if std.length(shardSelectors) > 0 then
    std.flatMap(
      function(shardSelector) errorAlerts(
        shardSelector.threshold,
        { type: service.type, component: sli.name, shard: shardSelector.shard } + extraSelector
      ),
      shardSelectors
    )
  else
    local errorRateSLO = getThresholdSLOValue(service, sli, alertDescriptor, 'errorRatio');
    errorAlerts(errorRateSLO, { type: service.type, component: sli.name } + extraSelector);

// Generates an apdex alert for an SLI
local apdexAlertForSLI(service, sli, alertDescriptors, extraSelector) =
  std.flatMap(
    function(descriptor)
      if descriptor.predicate(service, sli) then
        apdexAlertForSLIForAlertDescriptor(service, sli, descriptor, extraSelector)
      else
        [],
    alertDescriptors
  );

// Generates an error rate alert for an SLI
local errorRateAlertsForSLI(service, sli, alertDescriptors, extraSelector) =
  std.flatMap(
    function(descriptor)
      if descriptor.predicate(service, sli) then
        errorAlertForSLIForAlertDescriptor(service, sli, descriptor, extraSelector)
      else
        [],
    alertDescriptors
  );

local trafficCessationAlertsForSLI(service, sli, alertDescriptors, extraSelector) =
  std.flatMap(
    function(descriptor)
      if descriptor.predicate(service, sli) then
        trafficCessationAlertForSLIForAlertDescriptor(service, sli, descriptor, extraSelector)
      else
        [],
    alertDescriptors
  );


local alertsForService(service, alertDescriptors, extraSelector, tenant=null) =
  local alertingSlis = std.filter(
    function(sli) !sli.experimental,
    service.listServiceLevelIndicators()
  );

  local rules = std.map(
    function(alert)
      objects.nestedMerge(alert, {
        annotations: {
          grafana_datasource_id: tenant,
        },
      }),
    std.flatMap(
      function(sli)
        (
          if sli.hasApdexSLO() && sli.hasApdex() then
            apdexAlertForSLI(service, sli, alertDescriptors, extraSelector)
          else
            []
        )
        +
        (
          if sli.hasErrorRateSLO() && sli.hasErrorRate() then
            errorRateAlertsForSLI(service, sli, alertDescriptors, extraSelector)
          else
            []
        )
        +
        (
          trafficCessationAlertsForSLI(service, sli, alertDescriptors, extraSelector)
        ),
      alertingSlis
    )
  );

  alerts.processAlertRules(rules);


function(service, alertDescriptors, groupExtras={}, extraSelector={}, tenant=null)
  local alertRules = alertsForService(service, alertDescriptors, extraSelector, tenant);
  if std.length(alertRules) > 0 then
    [{
      name: 'Service Component Alerts: %s' % [service.type],
      interval: '1m',
      rules: alertRules,
    } + groupExtras]
  else []
