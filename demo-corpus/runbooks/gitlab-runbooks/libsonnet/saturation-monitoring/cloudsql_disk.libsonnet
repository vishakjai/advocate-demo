local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

local excludedCloudSqlDisk = ['customersdot'];

local cloudsqlDefault = {
  severity: 's4',
  horizontallyScalable: true,
  local cloudsqlServices = metricsCatalog.findServicesWithTag(tag='cloud-sql') + metricsCatalog.findServicesWithTag(tag='runway-managed-postgres'),
  appliesTo: std.filter(function(s) !std.member(excludedCloudSqlDisk, s), cloudsqlServices),
  description: |||
    CloudSQL Disk utilization.

    See https://cloud.google.com/monitoring/api/metrics_gcp#gcp-cloudsql for
    more details
  |||,
  resourceLabels: ['database_id'],
  burnRatePeriod: '5m',
  staticLabels: {
    tier: 'inf',
    stage: 'main',
  },
  query: |||
    avg_over_time(stackdriver_cloudsql_database_cloudsql_googleapis_com_database_disk_utilization{%(selector)s}[%(rangeInterval)s])
  |||,
  slos: {
    soft: 0.85,
    hard: 0.90,
  },
};

{
  cloudsql_disk: resourceSaturationPoint(cloudsqlDefault {
    title: 'CloudSQL Disk Utilization',
    grafana_dashboard_uid: 'sat_cloudsql_disk',
  }),
  customersdot_cloudsql_disk: resourceSaturationPoint(cloudsqlDefault {
    title: 'CloudSQL CustomersDot Disk Utilization',
    appliesTo: excludedCloudSqlDisk,
    grafana_dashboard_uid: 'sat_customersdot_cloudsql_disk',
    slos: {
      soft: 0.95,
      hard: 0.98,
    },
  }),
}
