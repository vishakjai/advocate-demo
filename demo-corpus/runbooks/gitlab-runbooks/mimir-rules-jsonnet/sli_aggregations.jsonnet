local monitoredServices = (import 'gitlab-metrics-config.libsonnet').monitoredServices;
local intervalForDuration = import 'servicemetrics/interval-for-duration.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local unifiedRegistry = import 'servicemetrics/recording-rule-registry/unified-registry.libsonnet';

local rulesForService(serviceDefinition, extraSelector) =
  std.flatMap(
    function(burnRate)
      unifiedRegistry.ruleGroupsForServiceForBurnRate(serviceDefinition, burnRate, extraSelector),
    aggregationSet.defaultSourceBurnRates
  );

local outputPromYaml(groups) =
  std.manifestYamlDoc({
    groups: groups,
  });

local fileForService(service, extraSelector={}) =
  local ruleGroups = rulesForService(
    service,
    extraSelector
  );
  if std.length(std.prune(ruleGroups)) > 0 then
    {
      'sli-aggregations':
        outputPromYaml(ruleGroups),
    }
  else
    {};

std.foldl(
  function(memo, service)
    memo + separateMimirRecordingFiles(
      function(service, selector, _, _)
        fileForService(service, extraSelector=selector),
      service,
    ),
  monitoredServices,
  {}
)
