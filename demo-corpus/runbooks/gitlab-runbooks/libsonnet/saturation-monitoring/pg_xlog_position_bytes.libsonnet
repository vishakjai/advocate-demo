local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_xlog_position_bytes: resourceSaturationPoint({
    title: 'PostgreSQL WAL Generation Rate',
    severity: 's2',
    horizontallyScalable: false,
    appliesTo: metricsCatalog.findServicesWithTag(tag='patroni'),
    description: |||
      PostgreSQL Write Ahead Log (WAL) generation rate measures how fast the primary database is producing WAL data.

      High WAL generation is a sign of an impending saturation limit with WAL receiver and/or WAL apply on replicas.
      At high WAL generation rates (approaching 180 MB/s), replicas may not be able to receive and apply the data
      fast enough to keep up with generation, leading to saturation-induced replication lag.

      High WAL generation could be caused by:
      - Query pattern changes
      - Processes modifying large amounts of data
      - Database maintenance operations
      - Increased write workload

      Replication lag means the data on the replicas will be stale compared to the data on the primaries.
      This could lead to:
      - The load balancer keeping sticky reads on the primary longer (more load on primary)
      - If replication lag exceeds 2 minutes, all read traffic redirects to primary (even more load on primary)
      - Potential data loss if an unexpected failover occurs

      On replicas, both CPU and disk IO increase with WAL generation rate, regardless of the content of that WAL data.

      When this threshold is breached, consider:
      - Investigating what caused the WAL spike using pg_stat_statements_wal_bytes and pg_stat_statements_wal_fpi metrics
      - Analyzing query patterns and optimizing queries that generate excessive WAL
      - Reviewing recent database maintenance operations
      - Monitoring replication lag on replicas
    |||,
    grafana_dashboard_uid: 'sat_pg_xlog_position_bytes',
    resourceLabels: ['type'],
    useResourceLabelsAsMaxAggregationLabels: true,
    burnRatePeriod: '5m',
    query:
      // Normalize to saturation threshold: 180 MB/s is the maximum WAL generation rate
      // that replicas can sustain for receiving and applying WAL data without falling behind
      // 180 * 1000000 (180 million bytes) represents 180 MB/s
      |||
        max by (%(aggregationLabels)s) (
          rate(pg_xlog_position_bytes{%(selector)s, shard="default"}[%(rangeInterval)s])
          and on (fqdn) pg_replication_is_replica == 0
        )
        / (180 * 1000000)
      |||,
    slos: {
      soft: 0.70,
      hard: 0.90,
    },
    capacityPlanning: {
      forecast_days: 730,
    },
  }),
}
