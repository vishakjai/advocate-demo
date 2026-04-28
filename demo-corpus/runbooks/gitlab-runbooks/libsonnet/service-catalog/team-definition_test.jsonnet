local teamDefinition = import 'team-definition.libsonnet';
local test = import 'test.libsonnet';

test.suite({
  testTeamDefaults: {
    actual: std.objectFields(teamDefinition.defaults),
    expect: ['ignored_components', 'issue_tracker', 'product_stage_group', 'send_slo_alerts_to_team_slack_channel'],
  },
  local validTeam = {
    name: 'scalability',
    send_slo_alerts_to_team_slack_channel: true,
    ignored_components: [],
    product_stage_group: 'scalability',
  },
  testTeamValidness: {
    actual: teamDefinition._validator.isValid(validTeam),
    expectThat: {
      result: true,
      description: 'team %s expected to be valid' % std.toString(validTeam),
    },
  },
  testTeamUnknownIgnoredComponent: {
    actual: validTeam { ignored_components: ['graphql_query_fake'] },
    expectMatchingValidationError: {
      validator: teamDefinition._validator,
      message: 'field ignored_components: only components %s are supported' % [std.join(', ', teamDefinition._serviceComponents)],
    },
  },
  testTeamUnknownProductStage: {
    actual: validTeam { product_stage_group: 'skalability' },
    expectMatchingValidationError: {
      validator: teamDefinition._validator,
      message: 'field product_stage_group: unknown stage group',
    },
  },
})
