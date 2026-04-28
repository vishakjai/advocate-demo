local metrics = import '../gitlab-metrics-config.libsonnet';

/*

Tamland manifest for get-hybrid

*/

local uniqServices(saturationPoints) = std.foldl(
  function(memo, definition) std.set(memo + definition.appliesTo),
  std.objectValues(saturationPoints),
  []
);

// Returns an object with fake dashboard links for all components as a workaround
local dummyDashboardsPerComponent() =
  {
    [component]: {
      name: component,
      url: '',
    }
    for component in std.objectFields(metrics.saturationMonitoring)
  };

local services(services) = {
  [service]: {
    name: service,
    capacityPlanning: {},

    // Workaround for now as we don't know where to link to and Tamland
    // requires this information
    overviewDashboard: { name: '', url: '' },
    resourceDashboard: dummyDashboardsPerComponent(),
  }
  for service in services
};

/*
Saturation points from 'servicemetrics/saturation-resources.libsonnet' carry all sorts of information.
This slices saturation points and only exposes what's relevant for Tamland.
*/
local saturationPoints = {
  local point = metrics.saturationMonitoring[name],

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
  for name in std.objectFields(metrics.saturationMonitoring)
};

local page(path, title, service_pattern) =
  {
    path: path,
    title: title,
    service_pattern: service_pattern,
  };

{
  'tamland/manifest.json': {
    defaults: {
      prometheus: {
        baseURL: 'http://kube-prometheus-stack-prometheus.monitoring:9090',
        defaultSelectors: {},
        serviceLabel: 'type',
        queryTemplates: {
          quantile95_1h: 'max(gitlab_component_saturation:ratio_quantile95_1h{%s})',
          quantile95_1w: 'max(gitlab_component_saturation:ratio_quantile95_1w{%s})',
          quantile99_1h: 'max(gitlab_component_saturation:ratio_quantile99_1h{%s})',
          quantile99_1w: 'max(gitlab_component_saturation:ratio_quantile99_1w{%s})',
        },
      },
    },
    services: services(uniqServices(metrics.saturationMonitoring)),
    saturationPoints: saturationPoints,
    teams: [],
    report: {
      pages: [
        page('all.md', 'All components', '.*'),
      ],
    },
  },
}
