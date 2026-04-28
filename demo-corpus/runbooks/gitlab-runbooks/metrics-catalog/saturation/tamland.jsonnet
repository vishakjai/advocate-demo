// Used to export all the metadata for saturation resources so that
// Tamland can use it as a file.
local saturation = import 'servicemetrics/saturation-resources.libsonnet';
local saturation = import 'servicemetrics/saturation-resources.libsonnet';
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local dashboard = import './grafana.libsonnet';
local prom = import './prom.libsonnet';

local uniqServices(saturationPoints) = std.foldl(
  function(memo, definition) std.set(memo + definition.appliesTo),
  std.objectValues(saturationPoints),
  []
);

// To reduce the size of saturation manifest, truncate raw catalog to essential fields required by Tamland.
// Service catalog is not to be confused with metrics catalog, refer to https://gitlab.com/gitlab-com/runbooks/-/tree/master/services#schema
local truncateRawCatalogService(service) =
  {
    name: service.name,
    label: service.label,
    owner: service.owner,
  };

local saturationPointsByService(service) = std.foldl(
  function(arr, saturationPointName)
    if std.member(saturation[saturationPointName].appliesTo, service)
    then arr + [saturationPointName]
    else arr,
  std.objectFields(saturation),
  []
);

local resourceDashboardPerComponent(service) =
  {
    [component]: dashboard.resourceDashboard(service, saturation[component].grafana_dashboard_uid, component)
    for component in saturationPointsByService(service)
  };

local serviceDefinition(service) =
  local definition = metricsCatalog.getService(service);
  local shards = std.get(definition, 'shards');
  {
    capacityPlanning: definition.capacityPlanning,
    overviewDashboard: dashboard.overviewDashboard(service),
    resourceDashboard: resourceDashboardPerComponent(service),
  };

local services(services) =
  {
    [service]: serviceDefinition(service) + truncateRawCatalogService(serviceCatalog.lookupService(service))
    for service in services
  };

local page(path, title, service_pattern) =
  {
    path: path,
    title: title,
    service_pattern: service_pattern,
  };

/*
Saturation points from 'servicemetrics/saturation-resources.libsonnet' carry all sorts of information.
This slices saturation points and only exposes what's relevant for Tamland.
*/
local saturationPoints = {
  local point = saturation[name],

  [name]: {
    title: point.title,
    description: point.description,
    appliesTo: point.appliesTo,
    capacityPlanning: point.getCapacityPlanningForTamland(),
    horizontallyScalable: point.horizontallyScalable,
    severity: point.severity,
    slos: point.slos,
    raw_query: point.getRawQueryForTamland(),
  }
  for name in std.objectFields(saturation)
};


{
  defaults: {
    prometheus: prom.defaults,
    capacityPlanning: {
      ignore_outliers: [
        { start: '2025-12-22', end: '2026-01-05' },
        { start: '2026-12-21', end: '2027-01-04' },
      ],
    },
  },
  services: services(uniqServices(saturation)),
  saturationPoints: saturationPoints,
  teams: serviceCatalog.getRawCatalogTeams(),
  report: {
    pages: [
      page('api-git-web.md', 'API, Git, and Web', 'api|git|internal-api|web|websockets'),
      page('ci-runners.md', 'CI Runners', 'ci-runners'),
      page('customersdot.md', 'Customersdot', 'customersdot'),
      page('gitaly.md', 'Gitaly', 'gitaly'),
      page('kube.md', 'Kubernetes', 'kube|external-dns'),
      page('monitoring-logging.md', 'Monitoring and Logging', 'monitoring|logging|thanos'),
      page('patroni.md', 'Postgres (Patroni and PgBouncer)', 'patroni.*|pgbouncer.*|postgres.*'),
      page('redis.md', 'Redis', 'redis.*'),
      page('runway.md', 'Runway', std.join('|', metricsCatalog.findRunwayProvisionedServices() + metricsCatalog.findRunwayProvisionedDatastores() + ['runway'])),
      page('ai-gateway.md', 'AI Gateway', 'ai-gateway'),
      page('ai-assisted.md', 'AI-assisted', 'ai-assisted'),
      page('search-service.md', 'Search', 'search'),
      page('sidekiq.md', 'Sidekiq', 'sidekiq'),
      page('other.md', 'Other services', 'errortracking|atlantis|tracing'),
      page('saturation.md', 'Other Utilization and Saturation Forecasting', 'camoproxy|cloud-sql|consul|ext-pvs|frontend|google-cloud-storage|jaeger|kas|mailroom|nat|nginx|plantuml|registry|sentry|vault|web-pages|woodhouse|ops-gitlab-net|memorystore|pulp'),
    ],
  },
}
