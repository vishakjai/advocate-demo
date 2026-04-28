local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local monitoredServices = (import 'gitlab-metrics-config.libsonnet').monitoredServices;
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local aggregationSetTransformer = import 'servicemetrics/aggregation-set-transformer.libsonnet';

local outputPromYaml(groups) =
  std.manifestYamlDoc({ groups: groups });

local servicesWithSlis = std.filter(function(service) std.length(service.listServiceLevelIndicators()) > 0, monitoredServices);

local transformRuleGroups(aggregationSet, extraSourceSelector, service) =
  if aggregationSet.enabledForService(service) then
    local sourceSelector = extraSourceSelector { type: service.type };
    local source = aggregationSet.sourceAggregationSet { selector+: sourceSelector };
    aggregationSetTransformer.generateRecordingRuleGroups(
      sourceAggregationSet=source,
      targetAggregationSet=aggregationSet,
      extrasForGroup={}
    ) else [];

local aggregationsForService(service, selector, _extraArgs, _) =
  local perServiceAggregations = [
    set
    for set in aggregationSets.transformedAggregations
    if std.member(set.labels, 'type')
  ];
  std.foldl(
    function(memo, aggregationSet)
      local groups = transformRuleGroups(aggregationSet, selector, service);
      if std.length(groups) > 0 then
        memo {
          ['transformed-%s-aggregation' % [aggregationSet.id]]: outputPromYaml(groups),
        }
      else memo,
    perServiceAggregations,
    {}
  );

std.foldl(
  function(memo, service)
    memo + separateMimirRecordingFiles(
      aggregationsForService,
      service,
    ),
  servicesWithSlis,
  {}
)
