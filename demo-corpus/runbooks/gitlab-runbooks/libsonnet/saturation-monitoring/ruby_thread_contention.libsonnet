local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local selectors = import 'promql/selectors.libsonnet';

local excludedShards = std.set(['memory-bound', 'import-shared-storage']);

local commonDefinition = {
  title: 'Ruby Thread Contention',
  severity: 's3',
  horizontallyScalable: true,  // Add more replicas for achieve greater scalability
  appliesTo: std.filter(
    function(service) service != 'sidekiq',
    metricsCatalog.findServicesWithTag(tag='rails')
  ),
  description: |||
    Ruby (technically Ruby MRI), like some other scripting languages, uses a Global VM lock (GVL) also known as a
    Global Interpreter Lock (GIL) to ensure that multiple threads can execute safely. Ruby code is only allowed to
    execute in one thread in a process at a time. When calling out to c extensions, the thread can cede the lock to
    other thread while it continues to execute.

    This means that when CPU-bound workloads run in a multithreaded environment such as Puma or Sidekiq, contention
    with other Ruby worker threads running in the same process can occur, effectively slowing thoses threads down as
    they await GVL entry.

    Often the best fix for this situation is to add more workers by scaling up the fleet.
  |||,
  grafana_dashboard_uid: 'sat_ruby_thread_contention',
  resourceLabels: ['fqdn', 'pod'],  // We need both because `instance` is still an unreadable IP :|
  // Using a longer burnRatePeriod here will allow us to not alert on short peaks of utilization
  burnRatePeriod: '1h',
  quantileAggregation: 0.99,
  query: |||
    rate(ruby_process_cpu_seconds_total{%(selector)s}[%(rangeInterval)s])
  |||,
  slos: {
    soft: 0.85,
    hard: 0.95,
  },
};

local sidekiqDefinition = commonDefinition {
  title: 'Sidekiq Ruby Thread Contention',
  appliesTo: ['sidekiq'],
  grafana_dashboard_uid: 'sat_sidekiq_thread_contention',
  query: |||
    rate(ruby_process_cpu_seconds_total{%(shardSelector)s, %(selector)s}[%(rangeInterval)s])
  |||,
  queryFormatConfig: {
    shardSelector: selectors.serializeHash({ shard: { noneOf: excludedShards } }),
  },
  quantileAggregation: 0.75,
};

local excludedSidekiqDefinition = commonDefinition {
  title: 'Excluded Shards Sidekiq Ruby Thread Contention',
  appliesTo: ['sidekiq'],
  grafana_dashboard_uid: 'exclude_sidekiq_thread_contention',
  query: |||
    rate(ruby_process_cpu_seconds_total{%(shardSelector)s, %(selector)s}[%(rangeInterval)s])
  |||,
  queryFormatConfig: {
    shardSelector: selectors.serializeHash({ shard: excludedShards }),
  },
  capacityPlanning: {
    strategy: 'exclude',
  },
};

{
  ruby_thread_contention: resourceSaturationPoint(commonDefinition),
  sidekiq_thread_contention: resourceSaturationPoint(sidekiqDefinition),
  excluded_sidekiq_thread_contention: resourceSaturationPoint(excludedSidekiqDefinition),
}
