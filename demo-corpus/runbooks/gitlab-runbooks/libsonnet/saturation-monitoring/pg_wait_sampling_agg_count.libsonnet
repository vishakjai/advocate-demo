local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

// Note: multiple by 100 as we have 100 samples per second on pg_wait_event which is sampled every 10ms
// Defined by pg_wait_sampling.profile_period: https://github.com/postgrespro/pg_wait_sampling/.

local bufferMapping = resourceSaturationPoint({
  title: 'PostgreSQL BufferMapping LWLock Contention',
  severity: 's2',
  horizontallyScalable: false,
  appliesTo: metricsCatalog.findServicesWithTag(tag='patroni'),
  description: |||
    BufferMapping LWLock contention indicates PostgreSQL's shared buffer pool is thrashing.

    This occurs when the workload's working set no longer fits well into the pool of shared buffers,
    causing frequent evictions that severely degrade query performance. The instance-wide bottleneck
    becomes contention for the BufferMapping LWLocks, which mediate evicting pages from shared buffers.

    This metric uses the pg_wait_sampling extension to provide high-frequency sampling of wait events
    for more accurate monitoring than traditional pg_stat_activity sampling.

    When this threshold is breached, consider:
    - Reducing query concurrency per PostgreSQL instance
    - Adding another replica to spread workload
    - Tuning queries to reduce buffer usage
    - Analyzing which queries are driving buffer churn
  |||,
  grafana_dashboard_uid: 'sat_pg_wait_buffer_mapping',
  resourceLabels: ['wait_event'],
  useResourceLabelsAsMaxAggregationLabels: true,
  burnRatePeriod: '5m',
  query: |||
    (
      max by (%(aggregationLabels)s) (
        rate(pg_wait_sampling_agg_count{%(selector)s, shard="default", wait_type="LWLock", wait_event="BufferMapping"}[5m])
        /
        on (fqdn) group_left() (sum(pg_stat_activity_count{%(selector)s, datname="gitlabhq_production", shard="default", state!~'idle.*'}) by (fqdn) * 100)
      )
    )
  |||,
  slos: {
    soft: 0.70,
    hard: 0.80,
  },
});

local lockManager = resourceSaturationPoint({
  title: 'PostgreSQL LockManager LWLock Contention',
  severity: 's2',
  horizontallyScalable: false,
  appliesTo: metricsCatalog.findServicesWithTag(tag='patroni'),
  description: |||
    LockManager LWLock contention indicates high contention for PostgreSQL's lock management system.

    This occurs when the number of requested locks entries for the same backend process is higher than 16, which is the value of FP_LOCK_SLOTS_PER_BACKEND, then the lock manager uses the  DEFAULT non–fast path lock method.
    PostgreSQL. High LockManager contention can indicate issues such as:
    - A large number of concurrent active sessions are accessing a table with many partitions and/or with many indexes;
    - The database is experiencing a connection storm due to slow queries response time;
    - A large number of sessions query a parent table without pruning partitions.
    - A data definition language (DDL), data manipulation language (DML), or a maintenance command exclusively locks either a busy relation or tuples that are frequently accessed or modified.

    This metric uses the pg_wait_sampling extension to provide high-frequency sampling of wait events
    for more accurate monitoring than traditional pg_stat_activity sampling.

    When this threshold is breached, consider:
    - Adding another replica to spread workload
    - Analyzing which queries are driving lock spike, and consider:
      - reducing number of indexes on the affected tables (any unused index should be dropped immediately);
      - tune the query to scan a smaller set of partitions, by using partition pruning;
      - tune queries for fast path locking (try to reduce number of relations per query to fewer than 16)
    - Reduce hardware bottlenecks;
    - Tune for regular `Lock` wait events, eg. `Lock:Relation`, `Lock:transactionid` or `Lock:tuple`. If the preceding events appear high in the list, consider tuning these wait events first. These events can be a driver for `LWLock:lock_manager`.
  |||,
  grafana_dashboard_uid: 'sat_pg_wait_lock_manager',
  resourceLabels: ['wait_event'],
  useResourceLabelsAsMaxAggregationLabels: true,
  burnRatePeriod: '5m',
  query: |||
    (
      max by (%(aggregationLabels)s) (
        rate(pg_wait_sampling_agg_count{%(selector)s, shard="default", wait_type="LWLock", wait_event="LockManager"}[5m])
        /
        on (fqdn) group_left() (sum(pg_stat_activity_count{%(selector)s, datname="gitlabhq_production", shard="default", state!~'idle.*'}) by (fqdn) * 100)
      )
    )
  |||,
  slos: {
    soft: 0.70,
    hard: 0.80,
  },
});

{
  pg_wait_sampling_buffer_mapping: bufferMapping,
  pg_wait_sampling_lock_manager: lockManager,
}
