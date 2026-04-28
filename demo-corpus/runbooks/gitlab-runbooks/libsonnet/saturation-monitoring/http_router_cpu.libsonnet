local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  http_router_cpu: resourceSaturationPoint({
    title: 'HTTP Router CPU P999 Budget',
    severity: 's3',  // Temporary disabled until we figure out https://gitlab.com/gitlab-com/gl-infra/capacity-planning-trackers/gitlab-com/-/issues/2026 to prevent pager noise.
    horizontallyScalable: true,
    appliesTo: ['http-router'],
    description: |||
      Maximum HTTP Router CPU time spent on any request for the fastest 99.9% of requests.

      The more time on the CPU we spend the more latency the HTTP Router is adding to every request.
      This also has a direct impact on [cost](https://developers.cloudflare.com/workers/platform/pricing/#workers) for HTTP Router.

      For profiling a worker follow https://developers.cloudflare.com/workers/observability/dev-tools/cpu-usage/
    |||,
    grafana_dashboard_uid: 'http-router-capacity-review',
    resourceLabels: ['script_name'],
    queryFormatConfig: {
      maxResponseTimeMs: 50,
    },
    query: |||
      max_over_time(cloudflare_worker_cpu_time{quantile="P999", %(selector)s}[%(rangeInterval)s]) / (%(maxResponseTimeMs)s * 1000)
    |||,
    slos: {
      // 40% of 50ms => 20ms
      soft: 0.4,
      // 80% of 50ms => 40ms
      hard: 0.8,
    },
  }),
}
