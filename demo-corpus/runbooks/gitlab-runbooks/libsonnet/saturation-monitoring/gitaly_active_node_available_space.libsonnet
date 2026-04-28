local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local selectors = import 'promql/selectors.libsonnet';

{
  gitaly_active_node_available_space: resourceSaturationPoint({
    title: 'Gitaly Active Node Available Space',
    severity: 's2',
    horizontallyScalable: true,
    appliesTo: ['gitaly'],
    alertRunbook: 'gitaly/gitalyctl/#stopping-migration-during-emergency',
    description: |||
      Available space on active gitaly nodes

      Active nodes are Gitaly nodes that are currently receiving new repositories

      We allow new Gitaly nodes to receive traffic until their disk is about 75%
      full. After which we mark the weight of the node as 0 in the
      [Gitaly shard weights assigner](https://gitlab.com/gitlab-com/gl-infra/gitaly-shard-weights-assigner/-/blob/master/assigner.rb#L9).

      To make sure we always have enough shards receiving new repositories, we want
      to have at least 8% of the total storage to be available for new projects.
      When this resource gets saturated, we could be creating to many projects on
      a limited set of nodes, which could cause these nodes to be busier than
      usual. To add new nodes start a new change issue with `/change declare` in Slack,
      and select the `change_gitaly_storage_creation.md` template.
    |||,
    grafana_dashboard_uid: 'sat_gitaly_active_available_space',
    resourceLabels: ['shard'],
    query: |||
      1 - (
        sum by (%(aggregationLabels)s) (
          (
            node_filesystem_avail_bytes{%(selector)s, %(gitalyDiskSelector)s} -
            (node_filesystem_size_bytes{%(selector)s, %(gitalyDiskSelector)s} * 0.20)
          )
          and
          (instance:node_filesystem_avail:ratio{%(selector)s, %(gitalyDiskSelector)s} > 0.20)
        )
        /
        sum by (%(aggregationLabels)s)(
          node_filesystem_size_bytes{%(selector)s, %(gitalyDiskSelector)s}
        )
      )
    |||,
    queryFormatConfig: {
      gitalyDiskSelector: selectors.serializeHash({
        shard: { oneOf: ['default'] },
        mountpoint: '/var/opt/gitlab',
        fqdn: { re: 'gitaly-.*-stor-.*' },
      }),
    },
    slos: {
      soft: 0.95,
      hard: 0.965,
    },
    capacityPlanning: {
      forecast_days: 30,
    },
  }),
}
