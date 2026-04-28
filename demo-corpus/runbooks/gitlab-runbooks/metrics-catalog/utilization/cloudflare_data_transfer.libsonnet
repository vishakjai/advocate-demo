local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local utilizationMetric = metricsCatalog.utilizationMetric;

{
  cloudflare_data_transfer: utilizationMetric({
    title: 'Cloudflare Network Total Data Transfer',
    unit: 'bytes',
    appliesTo: ['cloudflare'],
    description: |||
      Tracks total data transfer across the cloudflare network
    |||,
    rangeDuration: '1d',
    resourceLabels: ['zone'],
    query: |||
      sum by (%(aggregationLabels)s) (
        rate(cloudflare_zone_bandwidth_country{%(selector)s}[%(rangeDuration)s])
      )
    |||,
  }),
}
