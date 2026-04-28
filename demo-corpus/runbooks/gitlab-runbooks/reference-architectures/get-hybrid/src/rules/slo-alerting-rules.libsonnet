local config = (import 'gitlab-metrics-config.libsonnet');
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local serviceAlertsGenerator = import 'slo-alerts/service-alerts-generator.libsonnet';

// Minimum operation rate thresholds:
// This is to avoid low-volume, noisy alerts.
// See docs/metrics-catalog/service-level-monitoring.md for more details
// of how minimumSamplesForMonitoring works
local minimumSamplesForMonitoring = std.get(config.options, 'minimumSamplesForMonitoring', 3600);
local minimumOpsRateForMonitoring = std.get(config.options, 'minimumOpsRateForMonitoring', null);
local minimumSamplesForTrafficCessation = 300;

local alertDescriptors = [
  {
    predicate: function(service, sli) !sli.shardLevelMonitoring,
    alertSuffix: '',
    alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service',
    alertExtraDetail: null,
    aggregationSet: config.aggregationSets.componentSLIs,
    minimumSamplesForMonitoring: minimumSamplesForMonitoring,
    minimumOpsRateForMonitoring: minimumOpsRateForMonitoring,
    alertForDuration: null,  // Use default for window...
    trafficCessationSelector: {},
    minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
  },
  {
    predicate: function(service, sli) sli.shardLevelMonitoring,
    alertSuffix: 'SingleShard',
    alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service on shard `{{ $labels.shard }}`',
    alertExtraDetail: 'Since the `{{ $labels.type }}` service is not fully redundant, SLI violations on a single shard may represent a user-impacting service degradation.',
    aggregationSet: config.aggregationSets.shardComponentSLIs,
    minimumSamplesForMonitoring: minimumSamplesForMonitoring,
    minimumOpsRateForMonitoring: minimumOpsRateForMonitoring,
    alertForDuration: null,
    trafficCessationSelector: {},
    minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
  },
];

std.flatMap(
  function(service)
    serviceAlertsGenerator(service, alertDescriptors),
  metricsCatalog.services,
)
