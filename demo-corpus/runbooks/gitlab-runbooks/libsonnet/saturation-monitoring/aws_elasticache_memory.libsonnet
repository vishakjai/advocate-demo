local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';
local config = import './gitlab-metrics-config.libsonnet';

local elasticacheMonitoring = std.get(config.options, 'elasticacheMonitoring', false);

{
  [if elasticacheMonitoring then 'aws_elasticache_memory_saturation']: resourceSaturationPoint({
    title: 'Memory Saturation for an ElastiCache instance',
    severity: 's2',
    horizontallyScalable: false,
    appliesTo: ['elasticache'],
    description: |||
      Percentage of memory in the cluster that is in use. Uses aws_elasticache_database_memory_usage_percentage_maximum from CloudWatch metrics

      Additional details here: https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/CacheMetrics.Redis.html
    |||,
    grafana_dashboard_uid: 'aws_elasticache_memory_saturation',
    resourceLabels: [],
    linear_prediction_saturation_alert: '6h',  // Alert if this is going to exceed the hard threshold within 6h

    // This value is presented as a percentage.  We divide by 100 such that it is more consistent with our metrics system.
    query: 'aws_elasticache_database_memory_usage_percentage_maximum / 100',

    slos: {
      soft: 0.85,
      hard: 0.90,
      alertTriggerDuration: '30m',
    },
  }),
}
