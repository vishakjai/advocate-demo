local serviceAlertsGenerator = import 'slo-alerts/service-alerts-generator.libsonnet';
//
// Minimum operation rate thresholds:
// This is to avoid low-volume, noisy alerts.
// See docs/metrics-catalog/service-level-monitoring.md for more details
// of how minimumSamplesForMonitoring works
local minimumSamplesForMonitoring = 3600;
local minimumSamplesForNodeMonitoring = 3600;

// 300 requests in 30m required an hour ago before we trigger cessation alerts
// This is about 10 requests per minute, which is not that busy
// The difference between 0.1666 RPS and 0 PRS can occur on calmer periods
local minimumSamplesForTrafficCessation = 300;

// Most MWMBR alerts use a 2m period
// Initially for this alert, use a long period to ensure that
// it's not too noisy.
// Consider bringing this down to 2m after 1 Sep 2020
local nodeAlertWaitPeriod = '10m';

local alertDescriptors(aggregationSets) = [{
  predicate: function(service, sli) !sli.shardLevelMonitoring,
  alertSuffix: '',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service (`{{ $labels.stage }}` stage)',
  alertExtraDetail: null,
  aggregationSet: aggregationSets.componentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForMonitoring,
  alertForDuration: null,  // Use default for window...
  trafficCessationSelector: { stage: 'main' },  // Don't alert on cny stage traffic cessation for now
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}, {
  predicate: function(service, sli) service.monitoring.node.enabled,
  alertSuffix: 'SingleNode',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service on node `{{ $labels.fqdn }}`',
  alertExtraDetail: 'Since the `{{ $labels.type }}` service is not fully redundant, SLI violations on a single node may represent a user-impacting service degradation.',
  aggregationSet: aggregationSets.nodeComponentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForNodeMonitoring,
  alertForDuration: nodeAlertWaitPeriod,
  trafficCessationSelector: {},
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}, {
  predicate: function(service, sli) service.regional,
  alertSuffix: 'Regional',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service in region `{{ $labels.region }}`',
  alertExtraDetail: 'Note that this alert is specific to the `{{ $labels.region }}` region.',
  aggregationSet: aggregationSets.regionalComponentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForMonitoring,
  alertForDuration: null,  // Use default for window...
  trafficCessationSelector: { stage: 'main' },  // Don't alert on cny stage traffic cessation for now
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}, {
  predicate: function(service, sli) sli.shardLevelMonitoring,
  alertSuffix: 'SingleShard',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service on shard `{{ $labels.shard }}`',
  alertExtraDetail: 'Since the `{{ $labels.type }}` service is not fully redundant, SLI violations on a single shard may represent a user-impacting service degradation.',
  aggregationSet: aggregationSets.shardComponentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForMonitoring,
  alertForDuration: nodeAlertWaitPeriod,
  trafficCessationSelector: {},
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}];

local groupsForService(service, selector, aggregationSets, groupExtras={}, tenant=null) =
  local groups = serviceAlertsGenerator(
    service,
    alertDescriptors(aggregationSets),
    groupExtras=groupExtras,
    extraSelector=selector,
    tenant=tenant,
  );
  if std.length(groups) > 0 then
    {
      groups: groups,
    }
  else
    null;

groupsForService
