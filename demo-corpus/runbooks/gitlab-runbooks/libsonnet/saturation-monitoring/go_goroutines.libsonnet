local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  go_goroutines: resourceSaturationPoint({
    title: 'Go goroutines Utilization per Node',
    severity: 's2',
    dangerouslyThanosEvaluated: true,
    horizontallyScalable: true,
    appliesTo: std.setInter(
      std.set(metricsCatalog.findServicesWithTag(tag='golang')),
      std.set(metricsCatalog.findVMProvisionedServices() + metricsCatalog.findRunwayProvisionedServices())
    ),
    description: |||
      Go goroutines utilization per node.

      Goroutines leaks can cause memory saturation which can cause service degradation.

      A limit of 250k goroutines is very generous, so if a service exceeds this limit,
      it's a sign of a leak and it should be dealt with.
    |||,
    grafana_dashboard_uid: 'sat_go_goroutines',
    resourceLabels: ['fqdn', 'region', 'instance'],
    queryFormatConfig: {
      maxGoroutines: 250000,
    },
    query: |||
      sum by (%(aggregationLabels)s) (
        go_goroutines{%(selector)s}
      )
      /
      %(maxGoroutines)g
    |||,
    slos: {
      soft: 0.90,
      hard: 0.98,
    },
  }),
}
