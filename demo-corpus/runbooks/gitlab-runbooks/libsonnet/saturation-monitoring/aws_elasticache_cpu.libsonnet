local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';
local config = import './gitlab-metrics-config.libsonnet';

local elasticacheMonitoring = std.get(config.options, 'elasticacheMonitoring', false);

{
  [if elasticacheMonitoring then 'aws_elasticache_cpu_utilization']: resourceSaturationPoint({
    title: 'CPU Utilization per ElastiCache Instance',
    severity: 's2',
    horizontallyScalable: false,
    appliesTo: ['elasticache'],
    description: |||
      The percentage of available CPU used by the main Redis thread, as reported by `EngineCPUUtilization`.

      Additional details here: https://docs.aws.amazon.com/AmazonElastiCache/latest/red-ug/CacheMetrics.Redis.html
    |||,
    grafana_dashboard_uid: 'aws_elasticache_cpu_utilization',
    resourceLabels: [],
    linear_prediction_saturation_alert: '6h',  // Alert if this is going to exceed the hard threshold within 6h

    // This value is presented as a percentage.  We divide by 100 such that it is more consistent with our metrics system.
    query: 'aws_elasticache_engine_cpuutilization_maximum / 100',
    slos: {
      soft: 0.90,
      hard: 0.95,
      alertTriggerDuration: '15m',
    },
  }),
}
