local alerts = import 'alerts/alerts.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;


local labels = {
  rules_domain: 'general',
  severity: 's4',
  alert_type: 'cause',
};

local rules(extraSelector, tenant) = [
  // Ops Rate
  {
    alert: 'gitlab_component_opsrate_missing_series',
    expr: |||
      (
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_ops:rate{%(selector)s} offset 1d >= 0
        )
        unless
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_ops:rate{%(selector)s} >= 0
        )
      )
      and on (type, component)
      gitlab_component_service:mapping{%(selector)s}
    ||| % {
      selector: selectors.serializeHash({ monitor: { ne: 'global' } } + extraSelector),
    },
    'for': '1h',
    labels: labels,
    annotations: {
      title: 'Operation rate data for the `{{ $labels.component }}` component of the `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is missing',
      description: |||
        The data used to generate the `gitlab_component_ops:rate` metrics are missing for the
        `{{ $labels.component }}` component of the `{{ $labels.type }}` service. This
        might indicate that our observability has been affected.
      |||,
      grafana_dashboard_id: 'alerts-component_opsrate_missing/alerts-component-request-rate-series-missing',
      grafana_panel_id: stableIds.hashStableId('missing-series'),
      grafana_variables: 'environment,type,component,stage',
      grafana_min_zoom_hours: '24',
      grafana_datasource_id: tenant,
    },
  },
  {
    // Apdex
    alert: 'gitlab_component_apdex_missing_series',
    expr: |||
      (
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_apdex:ratio{%(selector)s} offset 1d >= 0
        )
        unless
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_apdex:ratio{%(selector)s}
        )
      )
      and on (type, component)
      gitlab_component_service:mapping{%(selector)s}
    ||| % {
      selector: selectors.serializeHash({ monitor: 'global' } + extraSelector),
    },
    'for': '1h',
    labels: labels,
    annotations: {
      title: 'Apdex for the `{{ $labels.component }}` component of the `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is missing',
      description: |||
        The data used to generate the `gitlab_component_apdex:ratio` metrics are missing for the
        `{{ $labels.component }}` component of the `{{ $labels.type }}` service. This
        might indicate that our observability has been affected.
      |||,
      grafana_dashboard_id: 'alerts-component_opsrate_missing/alerts-component-request-rate-series-missing',
      grafana_panel_id: stableIds.hashStableId('missing-series'),
      grafana_variables: 'environment,type,component,stage',
      grafana_min_zoom_hours: '24',
      grafana_datasource_id: tenant,
    },
  },
  {
    // Error Rate
    // For error rate, ignore the `cny` stage, as without much traffic,
    // the likelihood of errors will be reduced, leading to
    // `gitlab_component_error_missing_series` alerts
    alert: 'gitlab_component_error_missing_series',
    expr: |||
      (
        sum by (env, environment, tier, type, stage, component) (
          (gitlab_component_errors:rate{%(selector)s} offset 1d)
        )
        unless
        sum by (env, environment, tier, type, stage, component) (
          gitlab_component_errors:rate{%(selector)s}
        )
      )
      and on (type, component)
      gitlab_component_service:mapping{%(selector)s}
    ||| % {
      selector: selectors.serializeHash({ monitor: { ne: 'global' }, stage: { ne: 'cny' } } + extraSelector),
    },
    'for': '2h',
    labels: labels,
    annotations: {
      title: 'Error rate data for the `{{ $labels.component }}` component of the `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is missing',
      description: |||
        The data used to generate the `gitlab_component_errors:rate` metrics are missing for the
        `{{ $labels.component }}` component of the `{{ $labels.type }}` service. This
        might indicate that our observability has been affected.
      |||,
      grafana_dashboard_id: 'alerts-component_error_missing/alerts-component-error-rate-series-missing',
      grafana_panel_id: stableIds.hashStableId('missing-series'),
      grafana_variables: 'environment,type,component,stage',
      grafana_min_zoom_hours: '24',
      grafana_datasource_id: tenant,
    },
  },
];

separateMimirRecordingFiles(
  function(serviceDefinition, selector, extraSelector, tenant)
    {
      'missing-series-alerts': std.manifestYamlDoc({
        groups: [
          {
            name: 'missing_series_alerts.rules',
            rules: alerts.processAlertRules(rules(selector, tenant)),
          },
        ],
      }),
    }
)
