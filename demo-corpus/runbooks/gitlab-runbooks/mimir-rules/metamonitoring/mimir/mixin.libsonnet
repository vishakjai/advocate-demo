local mimir = import 'mimir/mixin.libsonnet';

mimir {
  _config+:: {
    product: 'Mimir',

    additionalAlertLabels: {
      team: 'observability',
      env: 'ops',
    },

    enableTenantAlerts: false,

    // Sets the p99 latency alert threshold for queries.
    cortex_p99_latency_threshold_seconds: 6,
  },
}
