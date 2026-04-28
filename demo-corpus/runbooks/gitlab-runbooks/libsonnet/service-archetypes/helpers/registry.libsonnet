local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;

local registryApdex(selector, satisfiedThreshold, toleratedThreshold=null, metricsFormat='migrating') =
  histogramApdex(
    histogram='registry_http_request_duration_seconds_bucket',
    selector=selector,
    satisfiedThreshold=satisfiedThreshold,
    toleratedThreshold=toleratedThreshold,
    metricsFormat=metricsFormat,
  );

local mainApdex(selector, customRouteSLIs) =
  local customizedRoutes = std.set(std.map(function(routeConfig) routeConfig.route, customRouteSLIs));
  local withoutCustomizedRouteSelector = selector {
    route: { noneOf: customizedRoutes },
  };

  registryApdex(selector + withoutCustomizedRouteSelector, satisfiedThreshold=2.5, toleratedThreshold=25);

local sliFromConfig(registryBaseSelector, defaultRegistrySLIProperties, config) =
  local selector = registryBaseSelector {
    route: { eq: config.route },
    method: { oneOf: config.methods },
  };
  local toleratedThreshold =
    if std.objectHas(config, 'toleratedThreshold') then
      config.toleratedThreshold
    else
      null;
  defaultRegistrySLIProperties + config {
    apdex: registryApdex(selector, config.satisfiedThreshold, toleratedThreshold),
    requestRate: rateMetric(
      counter='registry_http_request_duration_seconds_count',
      selector=selector
    ),
    significantLabels: ['method'],
  };

local customRouteApdexes(selector, defaultRegistrySLIProperties, customRouteSLIs) =
  std.foldl(
    function(memo, sliConfig) memo { [sliConfig.name]: sliFromConfig(selector, defaultRegistrySLIProperties, sliConfig) },
    customRouteSLIs,
    {}
  );

{
  /*
   * This apdex contains of the routes that do not have a customized apdex
   * When adding routes to the customApdexRouteConfig, they will get excluded
   * from this one.
   */
  mainApdex:: mainApdex,

  /*
   * This contains an apdex for all of the routes-method combinations that have
   * a custom configuration
   */
  apdexPerRoute:: customRouteApdexes,
}
