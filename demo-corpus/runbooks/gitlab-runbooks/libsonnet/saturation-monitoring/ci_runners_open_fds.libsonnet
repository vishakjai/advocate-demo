local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;

{
  ci_runners_open_fds: resourceSaturationPoint({
    title: 'CI Runners Open file descriptor utilization per instance',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: ['ci-runners'],
    description: |||
      Open file descriptor utilization per instance for CI Runners.

      CI Runners have different file descriptor usage patterns compared to other services,
      requiring lower SLO thresholds to ensure adequate capacity for job execution.

      Saturation on file descriptor limits may indicate a resource-descriptor leak in the application.

      As a temporary fix, you may want to consider restarting the affected process.
    |||,
    grafana_dashboard_uid: 'sat_ci_runners_open_fds',
    resourceLabels: ['job', 'instance'],
    query: |||
      (
        process_open_fds{%(selector)s}
        /
        process_max_fds{%(selector)s}
      )
      or
      (
        ruby_file_descriptors{%(selector)s}
        /
        ruby_process_max_fds{%(selector)s}
      )
      or
      (
        node_filefd_allocated{%(selector)s}
        /
        node_filefd_maximum{%(selector)s}
      )
    |||,
    slos: {
      soft: 0.30,
      hard: 0.40,
    },
  }),
}
