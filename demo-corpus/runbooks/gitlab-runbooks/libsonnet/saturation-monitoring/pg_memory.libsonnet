local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

{
  pg_anon_memory: resourceSaturationPoint({
    title: 'Anonymous Memory Utilization per Patroni Node (malloc)',
    appliesTo: metricsCatalog.findServicesWithTag(tag='patroni'),
    // TODO: route this alert to the DBREs directly.
    severity: 's2',
    horizontallyScalable: false,
    description: |||
      Tracking for explicitly allocated memory (malloc).

      On PostgreSQL nodes this will most likely be shared_buffers, or work_mem.
      If this value is higher than usual, that does not necessarily indicate imminant danger.
      Exceeding the treshold indicates that the DBRE's assumption of the memory distribution was incorrect.
      More memory is used for allocations like shared_buffers or work_mem and less memory is available
      for the vital file system cache. This can lead to increased query execution times.

      Notify the DBREs in #g_database_operations.

      More information about memory pressure on PostgreSQL systems can be found here,
      https://runbooks.gitlab.com/patroni/unhealthy_patroni_node_handling/#oom-and-memory-pressure
    |||,
    grafana_dashboard_uid: 'sat_patroni_anon_memory',
    resourceLabels: [labelTaxonomy.getLabelFor(labelTaxonomy.labels.node)],
    query: |||
      (
        node_memory_Active_anon_bytes{%(selector)s}
        +
        node_memory_Inactive_anon_bytes{%(selector)s}
      )
      /
      node_memory_MemTotal_bytes{%(selector)s}
    |||,
    slos: {
      soft: 0.25,
      hard: 0.30,
    },
    capacityPlanning: {
      strategy: 'exclude',
    },
  }),

  pg_memory: resourceSaturationPoint({
    title: 'Memory Utilization per Patroni Node',
    appliesTo: metricsCatalog.findServicesWithTag(tag='patroni'),
    // TODO: route this alert to the DBREs directly.
    severity: 's2',
    horizontallyScalable: false,
    description: |||
      Memory utilization per Patroni node.

      On our PostgreSQL nodes the majority of memory is not explicitly allocated but used for
      the file system cache, to reduce the needed read iops and improve query performance.
      Therefore we set a very low alerting treshold.
      Should it be reached this does not indicate that no memory is available for allocation,
      but that we might not have enough memory to cache our hot data.
      This can lead to performance degradation.

      Notify the DBREs in #g_database_operations.

      More information about memory presure on PostgreSQL systems can be found here,
      https://runbooks.gitlab.com/patroni/unhealthy_patroni_node_handling/#oom-and-memory-pressure
    |||,
    grafana_dashboard_uid: 'sat_patroni_memory',
    resourceLabels: [labelTaxonomy.getLabelFor(labelTaxonomy.labels.node)],
    query: |||
      1 - (
        node_memory_MemAvailable_bytes{%(selector)s}
        /
        node_memory_MemTotal_bytes{%(selector)s}
      )
    |||,
    slos: {
      soft: 0.55,
      hard: 0.60,
    },
    capacityPlanning: {
      strategy: 'exclude',
    },
  }),
}
