local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';
local config = import './gitlab-metrics-config.libsonnet';

local rdsMonitoring = std.get(config.options, 'rdsMonitoring', false);
local rdsMaxAllocatedStorageGB = std.get(config.options, 'rdsMaxAllocatedStorageGB', null);

{
  [if rdsMonitoring && rdsMaxAllocatedStorageGB != null then 'aws_rds_disk_space']: resourceSaturationPoint({
    title: 'Disk Space Utilization per RDS Instance',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: ['rds'],
    description: |||
      Disk space used by the database

      We use the disk space reported by all relations from `pg_database_size` and use this as a saturation point against the
      maximum size that RDS is configured too.  This may not be the size of the active disk as RDS autoscales storage for us.

      Additional details here: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-metrics.html#rds-cw-metrics-instance
    |||,
    grafana_dashboard_uid: 'aws_rds_disk_space',
    resourceLabels: [],
    linear_prediction_saturation_alert: '6h',  // Alert if this is going to exceed the hard threshold within 6h

    // Sum ALL relations stored on the RDS instance
    // `rdsMaxAllocatedStorage` is specified as GB, convert to bytes to match `pg_database_size_bytes`
    query: |||
      sum by (type) (pg_database_size_bytes)
      /
      (%(rdsMaxAllocatedStorageGB)s * (1024 * 1024 * 1024))
    |||,
    queryFormatConfig: {
      // Note that this value can be an integer bytes value, or a
      // PromQL expression, such as a recording rule
      rdsMaxAllocatedStorageGB: rdsMaxAllocatedStorageGB,
    },
    slos: {
      soft: 0.95,
      hard: 0.99,
      alertTriggerDuration: '30m',
    },
  }),
}
