local alerts = import 'alerts/alerts.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local defaultSelector = {
  stage: { ne: '' },
  tier: { ne: '' },
  type: { ne: '' },
};

local rules = function(selector=defaultSelector, tenant=null) {
  groups: [
    {
      name: 'kube_cause_alerts',
      rules: [
        // NOTE: some deployments have a very low maxSurge value, sometimes 1 container.
        // Therefore this alert checks that more than 50% of containers are in a stuck state
        // AND more than 0 containers are in a stuck state.
        alerts.processAlertRule({
          alert: 'KubeContainersWaitingInError',
          expr: |||
            sum by (type, env, tier, stage, cluster, container) (
              kube_pod_container_status_waiting_reason:labeled{
                %(selector)s,
                reason!="ContainerCreating",
              }
            )
            > 0
            >= on(type, env, tier, stage, cluster, container) (
              topk by(type, env, tier, stage, cluster, container) (1,
                kube_deployment_spec_strategy_rollingupdate_max_surge:labeled{%(selector)s}
              )
              * 0.5
            )
          ||| % { selector: selectors.serializeHash(selector) },
          'for': '20m',
          labels: {
            team: 'sre_reliability',
            severity: 's2',
            alert_type: 'cause',
            pager: 'pagerduty',
            runbook: 'kube/alerts/KubeContainersWaitingInError/',
          },
          annotations: {
            title: 'Containers for the `{{ $labels.type }}` service, `{{ $labels.stage }}` are unable to start.',
            description: |||
              More than 50% of the deployment's `maxSurge` setting consists of containers unable to start for reasons other than
              `ContainerCreating`.
            |||,
            grafana_dashboard_id: 'alerts-kube_containers_waiting/alerts-containers-waiting',
            grafana_min_zoom_hours: '6',
            grafana_variables: 'environment,type,stage,cluster',
            grafana_datasource_id: tenant,
          },
        }),
      ],
    },
  ],
};

rules
