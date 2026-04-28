local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local config = import './gitlab-metrics-config.libsonnet';

local dbPlatform = std.get(config, 'dbPlatform', null);

// All of the below metrics are reported by the postgres exporter
local originalQuery = |||
  (
    max without (series) (
      label_replace(pg_database_wraparound_age_datfrozenxid{%(selector)s}, "series", "datfrozenxid", "", "")
      or
      label_replace(pg_database_wraparound_age_datminmxid{%(selector)s}, "series", "datminmxid", "", "")
    )
    and on (instance, job) (pg_replication_is_replica{%(selector)s} == 0)
  )
  /
  (%(wraparoundValue)s)
|||;

// `pg_database_wraparound_age_datfrozenxid_seconds` provided by the postgres exporter
// `pg_database_wraparound_age_datminxid_seconds` provided by the postgres exporter
local rdsQuery = |||
  (
    max (
      pg_database_wraparound_age_datfrozenxid_seconds{%(selector)s}
      or
      pg_database_wraparound_age_datminmxid_seconds{%(selector)s}
    )
  )
  /
  (%(wraparoundValue)s)
|||;

{
  pg_xid_wraparound: resourceSaturationPoint({
    title: 'Transaction ID Wraparound',
    severity: 's1',
    horizontallyScalable: false,

    // Use patroni tag, not postgres since we only want clusters that have primaries
    // not postgres-archive, or postgres-delayed nodes for example
    // Add RDS for instances where RDS is leveraged
    appliesTo: metricsCatalog.findServicesWithTag(tag='postgres_with_primaries') + metricsCatalog.findServicesWithTag(tag='rds'),

    alertRunbook: 'patroni/pg_xid_wraparound_alert/',
    description: |||
      Risk of DB shutdown in the near future, approaching transaction ID wraparound.

      This is a critical situation.

      This saturation metric measures how close the database is to Transaction ID wraparound.

      When wraparound occurs, the database will automatically shutdown to prevent data loss, causing a full outage.

      Recovery would require entering single-user mode to run vacuum, taking the site down for a potentially multi-hour maintenance session.

      To avoid reaching the db shutdown threshold, consider the following short-term actions:

      1. Escalate to the SRE Datastores team, and then,

      2. Find and terminate any very old transactions. The runbook for this alert has details.  Do this first.  It is the most critical step and may be all that is necessary to let autovacuum do its job.

      3. Run a manual vacuum on tables with oldest relfrozenxid.  Manual vacuums run faster than autovacuum.

      4. Add autovacuum workers or reduce autovacuum cost delay, if autovacuum is chronically unable to keep up with the transaction rate.

      Long running transaction dashboard: <https://dashboards.gitlab.net/d/alerts-long_running_transactions/alerts-long-running-transactions?orgId=1>
    |||,
    grafana_dashboard_uid: 'sat_pg_xid_wraparound',
    resourceLabels: ['datname'],
    queryFormatConfig: {
      // Transaction ID's contain at most 2^32 available ID's.  Postgres (>= version 14) reserves 3 million of said ID's
      wraparoundValue: '2^31 - 3000000',
    },
    query: if dbPlatform == 'rds' then rdsQuery else originalQuery,
    slos: {
      soft: 0.60,
      hard: 0.70,
    },
  }),
}
