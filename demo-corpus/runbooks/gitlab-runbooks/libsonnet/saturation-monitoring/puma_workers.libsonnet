local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;

{
  puma_workers: resourceSaturationPoint({
    title: 'Puma Worker Saturation',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findServicesWithTag(tag='puma'),
    description: |||
      Puma thread utilization.

      Puma uses a fixed size thread pool to handle HTTP requests. This metric shows how many threads are busy handling requests. When this resource is saturated,
      we will see puma queuing taking place. Leading to slowdowns across the application.

      Puma saturation is usually caused by latency problems in downstream services: usually Gitaly or Postgres, but possibly also Redis.
      Puma saturation can also be caused by traffic spikes.
    |||,
    grafana_dashboard_uid: 'sat_puma_workers',
    resourceLabels: [],
    query: |||
      sum by(%(aggregationLabels)s) (avg_over_time(sum without (pid,worker) (puma_active_connections{%(selector)s})[%(rangeInterval)s:]))
      /
      sum by(%(aggregationLabels)s) (sum without (pid,worker) (puma_max_threads{pid="puma_master", %(selector)s}))
    |||,
    slos: {
      soft: 0.85,
      hard: 0.90,
    },
  }),
}
