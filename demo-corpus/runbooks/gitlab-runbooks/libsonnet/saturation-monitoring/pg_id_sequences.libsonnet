local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;

{
  pg_id_sequences: resourceSaturationPoint({
    title: 'Postgres IDs sequence capacity',
    severity: 's1',
    horizontallyScalable: false,
    appliesTo: ['patroni', 'patroni-ci'],
    description: |||
      This measures all ID column's sequence capacity, each cell gets it's sequence range from the topology service and
      it's critically important that we do not reach saturation on these ID columns as GitLab (particular instance/cell)
      will stop to work otherwise.

      This tracks both int4 (in legacy cell) and int8 IDs.
    |||,
    grafana_dashboard_uid: 'sat_pg_id_sequences',
    burnRatePeriod: '5m',
    resourceLabels: ['fully_qualified_sequencename'],
    query: |||
      max by (%(aggregationLabels)s) (
        gitlab_pg_sequences_current_value{%(selector)s} / gitlab_pg_sequences_max_value{%(selector)s}
      )
    |||,
    slos: {
      soft: 0.50,
      hard: 0.90,
    },
    capacityPlanning: {
      forecast_days: 365,
    },
  }),
}
