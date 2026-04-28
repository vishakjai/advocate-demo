local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  pending_builds: resourceSaturationPoint({
    title: 'Hosted Runner Manager Concurrency Limit',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: ['hosted-runners'],
    description: |||
      Hosted Runner Manager Concurrency Limit.

      For more information, see: https://runbooks.gitlab.com/hosted-runners/#alerts
    |||,
    resourceLabels: ['hosted-runners'],
    staticLabels: {
      type: 'hosted-runners',
      tier: 'inf',
    },
    grafana_dashboard_uid: 'gitlab_runner_concurrent',
    query: |||
      (
        sum by (shard, type) (gitlab_runner_jobs)
      /
        sum by (shard, type) (gitlab_runner_concurrent)
      )
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
