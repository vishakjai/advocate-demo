local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';
local teamDefinition = import 'team-definition.libsonnet';
local test = import 'test.libsonnet';

local services = [
  {
    type: 'api',
    serviceDependencies: {
      gitaly: true,
      'memorystore-redis-tracechunks': true,
      'redis-sidekiq': true,
      'redis-cluster-cache': true,
      redis: true,
    },
  },
  {
    type: 'gitaly',
    serviceDependencies: {
      gitaly: true,
    },
  },
  {
    type: 'frontend',
    serviceDependencies: {
      api: true,
    },
  },
  {
    type: 'web',
    serviceDependencies: {
      redis: true,
      gitaly: true,
    },
  },
  {
    type: 'pages',
    serviceDependencies: {
      pgbouncer: true,
    },
  },
  {
    type: 'pgbouncer',
    serviceDependencies: {
      patroni: true,
    },
  },
  { type: 'woodhouse' },
  { type: 'patroni' },
  { type: 'redis' },
  { type: 'memorystore-redis-tracechunks' },
  { type: 'redis-cluster-cache' },
  { type: 'redis-sidekiq' },
];

test.suite({
  testBlank: {
    actual: serviceCatalog.buildServiceGraph(services),
    expect: {
      api: { inward: ['frontend'], outward: ['gitaly', 'memorystore-redis-tracechunks', 'redis', 'redis-cluster-cache', 'redis-sidekiq'] },
      frontend: { inward: [], outward: ['api'] },
      gitaly: { inward: ['web', 'api'], outward: [] },  //  It does not include self-reference
      pages: { inward: [], outward: ['pgbouncer'] },
      patroni: { inward: ['pgbouncer'], outward: [] },
      pgbouncer: { inward: ['pages'], outward: ['patroni'] },
      redis: { inward: ['web', 'api'], outward: [] },
      'redis-cluster-cache': { inward: ['api'], outward: [] },
      'redis-sidekiq': { inward: ['api'], outward: [] },
      'memorystore-redis-tracechunks': { inward: ['api'], outward: [] },
      web: { inward: [], outward: ['gitaly', 'redis'] },
      woodhouse: { inward: [], outward: [] },  // forever alone
    },
  },
  testGetTeam: {
    actual: serviceCatalog.getTeam('observability'),
    expect: {
      alerts: ['thanos', 'ops', 'gstg'],
      cloud_cost: { cost_owner: 'SUP-ORG-10442' },
      ignored_components: [],
      issue_tracker: null,
      name: 'observability',
      product_stage_group: 'observability',
      send_slo_alerts_to_team_slack_channel: true,
      slack_alerts_channel: 'g_infra_observability_alerts',
      manager: 'lmcandrew',
      manager_slack: 'lmcandrew',
      slack_group: 'S04T0MZ236J',
      label: 'team::Observability',
      url: 'https://about.gitlab.com/handbook/engineering/infrastructure/team/scalability/#scalabilityobservability',
    },
  },
  testTeams: {
    // Filtering in order not to have a test that fails every time someone adds
    // a team
    actual: std.set(
      std.filterMap(
        function(team) team.name == 'package_registry' || team.name == 'observability',
        function(team) team.name,
        serviceCatalog.getTeams()
      )
    ),
    expect: std.set(['package_registry', 'observability']),
  },
  testLookupExistingTeamForStageGroup: {
    actual: serviceCatalog.lookupTeamForStageGroup('authentication'),
    expect: {
      cloud_cost: { cost_owner: 'NOT_ASSIGNED' },
      issue_tracker: null,
      name: 'authentication',
      product_stage_group: 'authentication',
      send_error_budget_weekly_to_slack: true,
      send_slo_alerts_to_team_slack_channel: false,
      slack_alerts_channel: 'g_sscs_authentication',
      slack_group: 'S0A76EAJSJH',
      slack_error_budget_channel: 'g_sscs_authentication',
      ignored_components: ['graphql_query'],
    },
    testLookupNonExistingTeamForStageGroup: {
      actual: serviceCatalog.lookupTeamForStageGroup('huzzah'),
      expect: {},
    },
  },
  testAllTeamsValidness: {
    actual: serviceCatalog.getTeams(),
    expectAll: teamDefinition._validator.isValid,
  },
})
