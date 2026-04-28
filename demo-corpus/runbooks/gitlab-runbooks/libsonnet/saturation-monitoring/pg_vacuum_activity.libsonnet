local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_vacuum_activity: resourceSaturationPoint({
    title: 'Postgres Autovacuum Activity',
    severity: 's3',
    horizontallyScalable: true,  // We can add more vacuum workers, but at a resource utilization cost

    appliesTo: metricsCatalog.findServicesWithTag(tag='postgres_vacuum_monitoring'),

    description: |||
      This measures the total saturation of autovacuum workers, as a percentage of total autovacuum capacity.
    |||,
    grafana_dashboard_uid: 'sat_pg_vacuum_activity',
    resourceLabels: [],
    burnRatePeriod: '1d',
    query: |||
      pg_stat_activity_autovacuum_active{%(selector)s}
      /
      pg_settings_autovacuum_max_workers{%(selector)s}
    |||,
    slos: {
      soft: 0.60,
      hard: 0.90,
    },
  }),
}
