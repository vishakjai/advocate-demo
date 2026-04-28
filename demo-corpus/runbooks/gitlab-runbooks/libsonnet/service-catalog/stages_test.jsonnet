local stages = import 'service-catalog/stages.libsonnet';
local test = import 'test.libsonnet';

test.suite({
  testBlank: {
    actual: stages.findStageGroupForFeatureCategory('user_profile').name,
    expect: 'Authentication',
  },
  testNotOwnedStageGroupForFeatureCategory: {
    actual: stages.findStageGroupForFeatureCategory('not_owned').name,
    expect: 'not_owned',
  },
  testNotOwnedStageGroupNameForFeatureCategory: {
    actual: stages.findStageGroupNameForFeatureCategory('not_owned'),
    expect: 'not_owned',
  },
  testNotOwnedStageNameForFeatureCategory: {
    actual: stages.findStageNameForFeatureCategory('not_owned'),
    expect: 'not_owned',
  },
  testStageGroupAddsKey: {
    actual: stages.stageGroup('authentication').key,
    expect: 'authentication',
  },
  testStageGroupAddsTeam: {
    actual: stages.stageGroup('authentication').slack_alerts_channel,
    expect: 'g_sscs_authentication',
  },
  testStageGroupNotOwnedLookup: {
    actual: stages.notOwned,
    expect: {
      key: 'not_owned',
      name: 'not_owned',
      stage: 'not_owned',
      feature_categories: [
        'not_owned',
        'unknown',
      ],
      issue_tracker: null,
      product_stage_group: null,
      send_slo_alerts_to_team_slack_channel: false,
      ignored_components: [],
    },
  },
  testFeatureCategoryMapCategories: {
    actual: std.objectFields(stages.featureCategoryMap),
    expectThat: {
      knownCategories: std.set(['source_code_management', 'code_review_workflow']),
      result:
        local intersection = std.setInter(self.knownCategories, self.actual);
        intersection == self.knownCategories,
      description: 'did not contain known categories: %s' % std.toString(self.knownCategories),
    },
  },
  testFeatureCategoryMapGroup: {
    // The feature category 'source_code_management' is owned by the 'source_code' group
    actual: stages.featureCategoryMap.source_code_management,
    expect: stages.stageGroup('source_code'),
  },
})
