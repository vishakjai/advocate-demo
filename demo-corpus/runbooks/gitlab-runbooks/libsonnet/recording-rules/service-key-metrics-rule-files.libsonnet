// This entire file is only used by Thanos and prometheus environments, so it can be removed
// when we only rely on Mimir.
local selectiveRegistry = (import 'servicemetrics/recording-rule-registry.libsonnet').selectiveRegistry;

local prometheusServiceGroupGenerator = (import 'servicemetrics/prometheus-service-group-generator.libsonnet') {
  config+: { recordingRuleRegistry: selectiveRegistry },
};

local outputPromYaml(groups, groupExtras) =
  std.manifestYamlDoc({
    groups: [
      groupExtras + group
      for group in groups
    ],
  });

local filesForService(service, componentAggregationSet, nodeAggregationSet, featureCategoryAggregationSet, shardAggregationSet, groupExtras) =
  {
    ['key-metrics-%s.yml' % [service.type]]:
      outputPromYaml(
        prometheusServiceGroupGenerator.recordingRuleGroupsForService(
          service,
          componentAggregationSet=componentAggregationSet,
          nodeAggregationSet=nodeAggregationSet,
          shardAggregationSet=shardAggregationSet
        ),
        groupExtras
      ),
  } + if service.hasFeatureCategorySLIs() then
    {
      ['feature-category-metrics-%s.yml' % [service.type]]:
        outputPromYaml(
          prometheusServiceGroupGenerator.featureCategoryRecordingRuleGroupsForService(
            service,
            aggregationSet=featureCategoryAggregationSet,
          ),
          groupExtras
        ),
    }
  else {};


local filesForServices(services, componentAggregationSet, nodeAggregationSet, featureCategoryAggregationSet, shardAggregationSet, groupExtras={}) =
  std.foldl(
    function(memo, service)
      memo + filesForService(service, componentAggregationSet, nodeAggregationSet, featureCategoryAggregationSet, shardAggregationSet, groupExtras),
    std.filter(function(s) std.length(s.listServiceLevelIndicators()) > 0, services),
    {}
  );

{
  filesForServices:: filesForServices,
}
