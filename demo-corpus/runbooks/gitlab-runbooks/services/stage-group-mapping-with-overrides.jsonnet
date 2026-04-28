local overrides = import './stage-group-mapping-overrides.jsonnet';
local mapping = import './stage-group-mapping.jsonnet';
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';
local objects = import 'utils/objects.libsonnet';

local validateStage = function(overrideGroup)
  std.all(
    std.map(
      function(groupKey) overrideGroup.stage == mapping[groupKey].stage,
      overrideGroup.merge_groups
    )
  );

local validateGroupsExistence(groupKeys) =
  std.all(
    std.map(function(groupKey) std.objectHas(mapping, groupKey), groupKeys)
  );

local mergedGroups = std.flatMap(
  function(overrideGroupKey)
    local overrideGroup = overrides[overrideGroupKey];
    if std.objectHas(overrideGroup, 'merge_groups') then
      assert validateGroupsExistence(overrideGroup.merge_groups) :
             'inexistent group(s) %s' % [overrideGroup.merge_groups];
      assert validateStage(overrideGroup) :
             'invalid stage %s' % [overrideGroup.stage];

      overrideGroup.merge_groups
    else
      [],
  std.objectFields(overrides)
);

local mergeGroupsForKey(mergedGroupKey) =
  local team = serviceCatalog.lookupTeamForStageGroup(mergedGroupKey);
  local overriddenGroup = team + overrides[mergedGroupKey];
  if std.objectHas(overriddenGroup, 'merge_groups') then
    local mergedFeatureCategories = std.flatMap(
      function(groupName) mapping[groupName].feature_categories,
      overrides[mergedGroupKey].merge_groups
    );
    objects.objectWithout(overriddenGroup, 'merge_groups') { feature_categories: mergedFeatureCategories }
  else
    overriddenGroup;

local mergeResult = {
  [mergedGroupKey]: mergeGroupsForKey(mergedGroupKey)
  for mergedGroupKey in std.objectFields(overrides)
};

std.foldl(
  function(memo, groupKey)
    local team = serviceCatalog.lookupTeamForStageGroup(groupKey);
    if std.member(mergedGroups, groupKey) then
      memo
    else
      memo { [groupKey]: team + mapping[groupKey] },
  std.objectFields(mapping),
  mergeResult
)
