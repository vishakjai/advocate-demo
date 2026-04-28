local selectors = import 'promql/selectors.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';

local rules = function(
  extraSelector,
  alert_name_prefix,
  service_metric_name,
  disable_metric_name,
  upper_bound_alert_title,
  upper_bound_alert_description,
  service_definition_doc_url,
  component_metric_name,
  lower_bound_alert_title,
  lower_bound_alert_description,
  stable_id_string,
  tenant=null
              )
  local selector = { monitor: 'global' } + extraSelector;
  [
    //###############################################
    // Operation Rate: how many operations is this service handling per second?
    // Apdex success Rate: how many successful operations?
    //###############################################
    // ------------------------------------
    // Upper bound thresholds exceeded
    // ------------------------------------
    // Warn: Rate above 2 sigma
    {
      alert: '%(alert_name_prefix)s_out_of_bounds_upper_5m' % { alert_name_prefix: alert_name_prefix },
      // gitlab_service:mapping rules are still recorded across environments
      // They apply to all environments
      expr: |||
        (
            (
              (%(service_metric_name)s:rate_5m{%(selector)s} -  %(service_metric_name)s:rate:prediction{%(selector)s}) /
            %(service_metric_name)s:rate:stddev_over_time_1w{%(selector)s}
          )
          >
          3
        )
        unless on(tier, type)
        gitlab_service:mapping:%(disable_metric_name)s{monitor="global"}
      ||| % {
        selector: selectors.serializeHash(selector),
        service_metric_name: service_metric_name,
        disable_metric_name: disable_metric_name,
      },
      'for': '5m',
      labels: {
        rules_domain: 'general',
        severity: 's4',
        alert_type: 'cause',
        alert_trigger: alert_name_prefix + '_anomaly',
      },
      annotations: {
        description: upper_bound_alert_description,
        runbook: '{{ $labels.type }}/',
        title: upper_bound_alert_title,
        grafana_dashboard_id: 'general-service/service-platform-metrics',
        grafana_panel_id: stableIds.hashStableId(stable_id_string),
        grafana_variables: 'environment,type,stage',
        grafana_min_zoom_hours: '12',
        grafana_datasource_id: tenant,
        link1_title: 'Definition',
        link1_url: service_definition_doc_url,
        promql_template_1: '%(service_metric_name)s:rate{environment="$environment", type="$type", stage="$stage"}' % { service_metric_name: service_metric_name },
        promql_template_2: '%(component_metric_name)s:rate{environment="$environment", type="$type", stage="$stage"}' % { component_metric_name: component_metric_name },
      },
    },
    // ------------------------------------
    // Lower bound thresholds exceeded
    // ------------------------------------
    // Warn: Rate below 2 sigma
    {
      alert: '%(alert_name_prefix)s_out_of_bounds_lower_5m' % { alert_name_prefix: alert_name_prefix },
      expr: |||
        (
            (
              (%(service_metric_name)s:rate_5m{%(selector)s} -  %(service_metric_name)s:rate:prediction{%(selector)s}) /
            %(service_metric_name)s:rate:stddev_over_time_1w{%(selector)s}
          )
          <
          -3
        )
        unless on(tier, type)
        gitlab_service:mapping:%(disable_metric_name)s{monitor="global"}
      ||| % {
        selector: selectors.serializeHash(selector),
        service_metric_name: service_metric_name,
        disable_metric_name: disable_metric_name,
      },
      'for': '5m',
      labels: {
        rules_domain: 'general',
        severity: 's4',
        alert_type: 'cause',
      },
      annotations: {
        description: lower_bound_alert_description,
        runbook: '{{ $labels.type }}/',
        title: lower_bound_alert_title,
        grafana_dashboard_id: 'general-service/service-platform-metrics',
        grafana_panel_id: stableIds.hashStableId(stable_id_string),
        grafana_variables: 'environment,type,stage',
        grafana_min_zoom_hours: '12',
        grafana_datasource_id: tenant,
        link1_title: 'Definition',
        link1_url: service_definition_doc_url,
        promql_template_1: '%(service_metric_name)s:rate{environment="$environment", type="$type", stage="$stage"}' % { service_metric_name: service_metric_name },
        promql_template_2: '%(component_metric_name)s:rate{environment="$environment", type="$type", stage="$stage"}' % { component_metric_name: component_metric_name },
      },
    },
  ];

rules
