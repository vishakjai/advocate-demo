local stages = import 'service-catalog/stages.libsonnet';
local array = import 'utils/array.libsonnet';
local objects = import 'utils/objects.libsonnet';
local crossoverMappings = objects.invert((import 'gitlab-metrics-config.libsonnet').stageGroupMappingCrossover);

local rules = std.flatMap(
  function(featureCategory)
    local stageGroup = stages.featureCategoryMap[featureCategory];
    local featureCategories = [featureCategory] + array.compact([std.get(crossoverMappings, featureCategory)]);
    std.map(
      function(category)
        {
          record: 'gitlab:feature_category:stage_group:mapping',
          labels: {
            feature_category: category,
            stage_group: stageGroup.key,
            product_stage: stageGroup.stage,
            monitor: 'global',
          },
          expr: '1',
        },
      featureCategories,
    ),
  std.objectFields(stages.featureCategoryMap)
);

[{
  name: 'Feature Category Stage group mapping',
  rules: rules,
  interval: '1m',
}]
