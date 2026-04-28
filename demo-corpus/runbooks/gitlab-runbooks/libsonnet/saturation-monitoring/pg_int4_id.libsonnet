local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  pg_int4_id: resourceSaturationPoint({
    title: 'Postgres int4 ID capacity',
    severity: 's1',
    horizontallyScalable: false,
    appliesTo: ['patroni', 'patroni-ci'],  // No point in using tags here: see https://gitlab.com/groups/gitlab-org/-/epics/4785
    description: |||
      This measures used int4 columns capacity in all postgres tables. It is critically important that we do not reach
      saturation on primary key columns as GitLab will stop to work at this point.

      The saturation point tracks all integer columns, so also foreign keys that might not match their source.

      IID columns are deliberatly ignored because they are scoped to a project/namespace.
    |||,
    grafana_dashboard_uid: 'sat_pg_int4_id',
    resourceLabels: ['column_name'],
    useResourceLabelsAsMaxAggregationLabels: true,
    burnRatePeriod: '5m',
    query: |||
      max by (%(aggregationLabels)s) (
        pg_int4_saturation_current_largest_value{%(selector)s,%(columnSelector)s} / pg_int4_saturation_column_max_value{%(selector)s,%(columnSelector)s}
      )
    |||,
    queryFormatConfig: {
      columnSelector: selectors.serializeHash({ column_name: { nre: '.+(.|-|_)iid' } }),
    },
    slos: {
      soft: 0.50,
      hard: 0.90,
    },
    capacityPlanning: {
      forecast_days: 365,
      saturation_dimensions_keep_aggregate: false,
      saturation_dimension_dynamic_lookup_query: |||
        count by(column_name) (
          last_over_time(gitlab_component_saturation:ratio{column_name!="", %(selector)s}[1w:1d] @ end())
        )
      |||,
      saturation_dimension_dynamic_lookup_limit: 300,
    },
  }),
}
