local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;
local config = import './gitlab-metrics-config.libsonnet';

local rdsMonitoring = std.get(config.options, 'rdsMonitoring', false);
local rdsInstanceRAMBytes = std.get(config.options, 'rdsInstanceRAMBytes', null);
local rdsInstanceMaxConnections = std.get(config.options, 'rdsInstanceMaxConnections', 'rdsInstanceMaxConnections');

{
  [if rdsMonitoring && rdsInstanceRAMBytes != null then 'aws_rds_used_connections']: resourceSaturationPoint({
    title: 'AWS RDS Used Connections',
    severity: 's2',
    horizontallyScalable: false,
    appliesTo: ['rds'],
    grafana_dashboard_uid: 'rds_used_connections',
    description: |||
      The number of client network connections to the database instance.

      Instance Type: %s

      Further details: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/rds-metrics.html#rds-cw-metrics-instance
    |||,
    resourceLabels: [],

    // RDS Leverages a special function for determining the maximm allowed
    // connections: `LEAST({DBInstanceClassMemory/9531392}, 5000)`
    // Reference: https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/CHAP_Limits.html
    // We leverage this as part of our query below.
    query: |||
      sum by (dbinstance_identifier, type) (aws_rds_database_connections_maximum)
      /
      ((%(rdsInstanceMaxConnections)s) or clamp_max((%(rdsInstanceRAMBytes)s)/9531392, 5000))
    |||,
    queryFormatConfig: {
      // Note that this value can be an integer bytes value, or a
      // PromQL expression, such as a recording rule
      rdsInstanceRAMBytes: rdsInstanceRAMBytes,
      // Note that this value by default is a string (name of the metric)
      // to ensure a valid PromQL expression
      // This is because this metric is optional but the query needs to always be well-formed.
      rdsInstanceMaxConnections: rdsInstanceMaxConnections,
    },
    slos: {
      soft: 0.90,
      hard: 0.95,
      alertTriggerDuration: '5m',
    },
  }),
}
