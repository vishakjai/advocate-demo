local stageGroupMapping = (import 'gitlab-metrics-config.libsonnet').stageGroupMapping;

local stageGroup(groupName) =
  stageGroupMapping[groupName] { key: groupName };

local stageGroups = std.map(stageGroup, std.objectFields(stageGroupMapping));

local stageGroupsWithoutNotOwned =
  std.filter(function(group) group.key != 'not_owned', stageGroups);

/**
 * Constructs a map of [featureCategory]stageGroup for featureCategory lookups
 */
local stageGroupMappingLookup = std.foldl(
  function(map, stageGroup)
    std.foldl(
      function(map, featureCategory)
        map {
          [featureCategory]: stageGroup,
        },
      stageGroup.feature_categories,
      map
    ),
  stageGroups,
  {}
);

local findStageGroupForFeatureCategory(featureCategory) =
  stageGroupMappingLookup[featureCategory];

local findStageGroupNameForFeatureCategory(featureCategory) =
  findStageGroupForFeatureCategory(featureCategory).name;

local findStageNameForFeatureCategory(featureCategory) =
  findStageGroupForFeatureCategory(featureCategory).stage;

local categoriesForStageGroup(groupName) =
  stageGroup(groupName).feature_categories;

local groupsForStage(stageName) = std.filter(
  function(stageGroupElement)
    stageGroupElement.stage == stageName,
  stageGroups
);

{
  /**
   * Given a feature category, returns the appropriate stage group
   */
  findStageGroupForFeatureCategory:: findStageGroupForFeatureCategory,

  /**
   * Given a feature category, returns the appropriate stage group name
   * will return `not_owned` for `not_owned` feature category
   */
  findStageGroupNameForFeatureCategory:: findStageGroupNameForFeatureCategory,

  /**
   * Given a feature category, returns the appropriate stage name
   * will return `not_owned` for `not_owned` feature category
   */
  findStageNameForFeatureCategory:: findStageNameForFeatureCategory,

  /**
   * Given a stage-group name will return an array of feature categories
   * Will result in an error if an unknown group name is passed
   */
  categoriesForStageGroup(groupName):: categoriesForStageGroup(groupName),

  /**
   * Given a stage-group name will return the stage group object
   * Will result in an error if an unknown group name is passed
   */
  stageGroup(groupName):: stageGroup(groupName),

  /**
   * Returns a map of featureCategory[stageGroup]
   **/
  featureCategoryMap:: stageGroupMappingLookup,

  /**
   * Returns the not owned group
   */
  notOwned:: stageGroupMapping.not_owned,

  /**
   * Return all the groups of a stage
   */
  groupsForStage: groupsForStage,

  /**
   * Return all stage groups
   */
  stageGroups: stageGroups,

  /**
   * Return all stage groups excluding the special not_owned pseudo-stage
   */
  stageGroupsWithoutNotOwned: stageGroupsWithoutNotOwned,
}
