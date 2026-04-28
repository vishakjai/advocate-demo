local stages = import 'service-catalog/stages.libsonnet';

local ruleGroupForStageGroup(stageGroup) = {
  name: 'Stage group Ignored components: %s - %s' % [stageGroup.stage, stageGroup.name],
  interval: '1m',
  rules: [
    {
      record: 'gitlab:ignored_component:stage_group',
      labels: {
        product_stage: stageGroup.stage,
        stage_group: stageGroup.key,
        component: ignoredComponent,
      },
      expr: '1',
    }
    for ignoredComponent in stageGroup.ignored_components
  ],
};

// Generates an array of rule groups, one for each stage group with non-zero number of ignored components
std.filterMap(
  function(group) std.length(group.ignored_components) > 0,
  ruleGroupForStageGroup,
  stages.stageGroups
)
