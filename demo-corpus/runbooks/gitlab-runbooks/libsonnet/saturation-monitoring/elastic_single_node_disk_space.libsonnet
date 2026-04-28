local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  elastic_single_node_disk_space: resourceSaturationPoint({
    title: 'Disk Utilization per Device per Node',
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['logging', 'search'],
    description: |||
      Disk utilization per device per node.
    |||,
    grafana_dashboard_uid: 'sat_elastic_node_disk_space',
    resourceLabels: ['name'],
    query: |||
      (
        (
          elasticsearch_filesystem_data_size_bytes{%(selector)s}
          -
          elasticsearch_filesystem_data_free_bytes{%(selector)s}
        )
        /
        elasticsearch_filesystem_data_size_bytes{%(selector)s}
        * on (name, cluster) group_left(role) (elasticsearch_nodes_roles{role=~"data_.*", role!~"data_(frozen|content)", %(selector)s} == 1)
      )
    |||,
    slos: {
      soft: 0.85,
      hard: 0.95,
    },
  }),
}
