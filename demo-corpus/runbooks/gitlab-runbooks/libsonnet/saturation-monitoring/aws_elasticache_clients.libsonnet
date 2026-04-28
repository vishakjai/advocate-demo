local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';
local config = import './gitlab-metrics-config.libsonnet';

local elasticacheMonitoring = std.get(config.options, 'elasticacheMonitoring', false);

{
  [if elasticacheMonitoring then 'aws_elasticache_client_utilization']: resourceSaturationPoint({
    title: 'Saturation of Clients per ElastiCache Instance',
    severity: 's2',
    horizontallyScalable: false,
    appliesTo: ['elasticache'],
    description: |||
      The percentage of available Redis Clients used.
    |||,
    grafana_dashboard_uid: 'aws_elasticache_client_utilization',
    resourceLabels: [],
    linear_prediction_saturation_alert: '6h',  // Alert if this is going to exceed the hard threshold within 6h

    // We're can't query the max clients configuration, but according to AWS, we're limited to 65,000; pending instance size
    // We currently do not deploy instances small enough, so we'll just use the hardcoded value that is most common for us
    // https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/ParameterGroups.Redis.html
    query: 'redis_connected_clients / 65000',
    slos: {
      soft: 0.90,
      hard: 0.95,
      alertTriggerDuration: '15m',
    },
  }),
}
