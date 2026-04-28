local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local applicationSlis = (import 'gitlab-slis/library.libsonnet');
local applicationSliAggregations = import 'gitlab-slis/aggregation-sets.libsonnet';
local aggregationSetTransformer = import 'servicemetrics/aggregation-set-transformer.libsonnet';
local monitoredServices = (import 'gitlab-metrics-config.libsonnet').monitoredServices;
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';

local thanosCompatibilityLabels = { monitor: 'global' };

local transformRuleGroups(sourceAggregationSet, targetAggregationSet, extraSourceSelector, emittingType, extrasForGroup={}) =
  aggregationSetTransformer.generateRecordingRuleGroups(
    sourceAggregationSet=sourceAggregationSet { selector+: extraSourceSelector },
    targetAggregationSet=targetAggregationSet,
    extrasForGroup=extrasForGroup,
    emittingType=emittingType,
  );

local groupsForApplicationSli(sli, extraSelector, emittingType) =
  local targetAggregationSet = applicationSliAggregations.targetAggregationSet(sli, extraStaticLabels=thanosCompatibilityLabels);
  local sourceAggregationSet = applicationSliAggregations.sourceAggregationSet(sli, recordingRuleRegistry=recordingRuleRegistry.unifiedRegistry);
  transformRuleGroups(sourceAggregationSet, targetAggregationSet, extraSelector, emittingType);

local outputPromYaml(groups) =
  std.manifestYamlDoc({
    groups: groups,
  });

// Application SLIs not used in the service catalog  will be aggregated here.
// These aggregations allow us to see what the metrics look like before adding
// an them, so we can validate they would not trigger alerts.
// If the application SLI is added to the service catalog, it will automatically
// generate `sli_aggregation:` recordings that can be reused everywhere. So no
// real need to duplicate them.
std.foldl(
  function(memo, serviceDefinition)
    local serviceSliNames = std.objectFields(serviceDefinition.serviceLevelIndicators);
    local serviceApplicationSliNames = std.setInter(std.set(serviceSliNames), std.set(applicationSlis.names));
    local serviceApplicationSliDefinitions = std.map(function(name) applicationSlis.get(name), serviceApplicationSliNames);
    memo + separateMimirRecordingFiles(
      function(service, selector, _extraArgs, _)
        local groups = std.flatMap(
          function(sli)
            local emittingTypes = serviceDefinition.serviceLevelIndicators[sli.name].emittedBy;
            std.flatMap(
              function(emittingType)
                groupsForApplicationSli(sli, selector { type: emittingType }, emittingType),
              emittingTypes,
            ),
          serviceApplicationSliDefinitions
        );
        {
          [if std.length(groups) > 0 then 'aggregated-application-sli-metrics']: outputPromYaml(groups),
        },
      serviceDefinition=serviceDefinition
    )
  ,
  monitoredServices,
  {}
)
