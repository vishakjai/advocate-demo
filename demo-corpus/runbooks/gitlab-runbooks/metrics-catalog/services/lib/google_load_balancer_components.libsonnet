local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

{
  // Creates a google load balancers component
  // for monitoring a load balancer via stackdriver metrics
  // loadBalancerName: the name of the load balancer
  // projectId: the Google ProjectID that the load balancer is declared in
  googleLoadBalancer(
    userImpacting,
    loadBalancerName,
    projectId,
    featureCategory='not_owned',
    team=null,
    trafficCessationAlertConfig=true,
    additionalToolingLinks=[],
    baseSelector={ url_map_name: loadBalancerName, project_id: projectId },
    serviceAggregation=true,
    extra={},
  )::
    metricsCatalog.serviceLevelIndicatorDefinition(extra {
      userImpacting: userImpacting,
      featureCategory: featureCategory,
      [if team != null then 'team']: team,
      trafficCessationAlertConfig: trafficCessationAlertConfig,

      staticLabels: {
        // TODO: In future, we may need to allow other stages here too
        // in which case we'll need to use a scheme similar that the one
        // we use for HAPRoxy
        stage: 'main',
      },

      requestRate: rateMetric(
        counter='stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count',
        selector=baseSelector
      ),

      errorRate: rateMetric(
        counter='stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count',
        selector=baseSelector { response_code_class: '500' },
      ),

      emittedBy: [],

      serviceAggregation: serviceAggregation,

      significantLabels: ['proxy_continent', 'response_code'],

      toolingLinks:
        if std.isString(loadBalancerName) && std.isString(projectId) then [
          toolingLinks.googleLoadBalancer(
            instanceId=loadBalancerName,
            project=projectId
          ),
        ] else []
               + additionalToolingLinks,
    }),
}
