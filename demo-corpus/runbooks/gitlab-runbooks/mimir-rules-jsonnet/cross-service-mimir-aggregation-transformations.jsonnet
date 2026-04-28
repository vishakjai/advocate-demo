local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local aggregationSetTransformer = import 'servicemetrics/aggregation-set-transformer.libsonnet';

local outputPromYaml(groups) =
  std.manifestYamlDoc({ groups: groups });

local crossServiceAggregations(_service, selector, extraArgs, _tenant) =
  // Right now, these are only the stage group aggregations
  // When we do https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/1361 to record information cross tenant
  // These are the recordings that we'll have to give access to the external tenants for recording.
  local crossServiceAggregationSets = [
    set
    for set in aggregationSets.transformedAggregations
    if !std.member(set.labels, 'type')
  ];
  std.foldl(
    function(memo, aggregationSet)
      local groups = aggregationSetTransformer.generateRecordingRuleGroups(
        sourceAggregationSet=aggregationSet.sourceAggregationSet { selector+: selector },
        targetAggregationSet=aggregationSet,
        extrasForGroup=extraArgs
      );
      if std.length(groups) > 0 then
        memo {
          ['transformed-%s-aggregation' % [aggregationSet.id]]: outputPromYaml(groups),
        }
      else memo,
    crossServiceAggregationSets,
    {}
  );

separateMimirRecordingFiles(crossServiceAggregations)
