local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local serviceAnomalyDetection = import 'recording-rules/service-anomaly-detection.libsonnet';
local monitoredServices = (import 'gitlab-metrics-config.libsonnet').monitoredServices;

local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local serviceAggregation = aggregationSets.serviceSLIs;

local outputPromYaml(groups) =
  std.manifestYamlDoc({ groups: groups });

local fileForService(service, selector, _extraArgs, _) = {
  service_anomaly_detection: outputPromYaml(
    serviceAnomalyDetection.recordingRuleGroupsFor(
      service.type,
      serviceAggregation,
      serviceAggregation.getOpsRateMetricForBurnRate,
      'ops rate',
      'gitlab_service_ops',
      'disable_ops_rate_prediction',
      selector { type: service.type },
    )
  ),
};

std.foldl(
  function(memo, service)
    memo + separateMimirRecordingFiles(
      fileForService,
      service,
    ),
  monitoredServices,
  {}
)
