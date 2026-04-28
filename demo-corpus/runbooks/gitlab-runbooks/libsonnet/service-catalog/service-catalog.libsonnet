local metricsConfig = import 'gitlab-metrics-config.libsonnet';
local rawCatalog = metricsConfig.serviceCatalog;
local allServices = metricsConfig.monitoredServices;
local miscUtils = import 'utils/misc.libsonnet';
local teamDefinition = import 'team-definition.libsonnet';

local serviceMap = {
  [x.name]: x
  for x in rawCatalog.services
};

local teamMap = std.foldl(
  function(result, team)
    assert !std.objectHas(result, team.name) : 'Duplicate definition for team: %s' % [team.name];
    result { [team.name]: teamDefinition.defaults + team },
  rawCatalog.teams,
  {}
);

local teamGroupMap = std.foldl(
  function(result, team)
    if team.product_stage_group != null then
      assert !std.objectHas(result, team.product_stage_group) : 'team %s already has a team with stage group %s' % [team.name, team.product_stage_group];
      result { [team.product_stage_group]: team }
    else
      result,
  std.objectValues(teamMap),
  {}
);

local buildServiceGraph(services) =
  std.foldl(
    function(graph, service)
      local dependencies =
        if std.objectHas(service, 'serviceDependencies') then
          miscUtils.arrayDiff(std.objectFields(service.serviceDependencies), [service.type])
        else
          [];
      if std.length(dependencies) > 0 then
        graph + {
          [dependency]: {
            inward: std.uniq([service.type] + graph[dependency].inward),
            outward: graph[dependency].outward,
          }
          for dependency in dependencies
        } + {
          [service.type]: {
            inward: graph[service.type].inward,
            outward: std.uniq(dependencies + graph[service.type].outward),
          },
        }
      else
        graph,
    services,
    std.foldl(
      function(graph, service) graph { [service.type]: { inward: [], outward: [] } },
      services,
      {}
    )
  );

local truncateRawCatalogTeam(team) =
  {
    name: team.name,
    label: if std.objectHas(team, 'label') then team.label else null,
    manager: if std.objectHas(team, 'manager') then team.manager else null,
  };

{
  lookupService(name)::
    if std.objectHas(serviceMap, name) then serviceMap[name],

  buildServiceGraph: buildServiceGraph,
  serviceGraph:: buildServiceGraph(allServices),

  getTeams()::
    std.objectValues(teamMap),

  lookupTeamForStageGroup(name)::
    if std.objectHas(teamGroupMap, name) then teamGroupMap[name] else teamDefinition.defaults,

  getTeam(teamName)::
    teamMap[teamName],

  findServices(filterFunc)::
    std.filter(filterFunc, rawCatalog.services),

  findKeyBusinessServices(includeZeroScore=false)::
    std.filter(
      function(service)
        std.objectHas(service, 'business') &&
        std.objectHas(service.business.SLA, 'overall_sla_weighting') &&
        (if includeZeroScore then service.business.SLA.overall_sla_weighting >= 0 else service.business.SLA.overall_sla_weighting > 0),
      rawCatalog.services
    ),

  getRawCatalogTeams()::
    std.map(
      function(team)
        truncateRawCatalogTeam(team)
      , rawCatalog.teams
    ),
}
