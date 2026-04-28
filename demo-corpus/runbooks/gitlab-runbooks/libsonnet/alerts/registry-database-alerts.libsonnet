local alerts = import 'alerts/alerts.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

function(selector={}, tenant=null)
  {
    groups: [
      {
        name: 'patroni-registry extra alerts',
        rules: [
          alerts.processAlertRule({
            alert: 'ContainerRegistryDBLoadBalancerReplicaPoolSize',
            expr: |||
              (
                sum by (env, environment, stage) (
                  pg_replication_is_replica{tier="db", type="patroni-registry", %(selector)s}
                ) - 1 # subtract 1 to exclude the backup replica, which is not advertised for load balancing
              )
              >
              max by (env, environment, stage) (
                registry_database_lb_pool_size{type="registry", %(selector)s}
              )
            ||| % { selector: selectors.serializeHash(selector) },
            'for': '5m',
            labels: {
              team: 'container_registry',
              severity: 's4',
              alert_type: 'symptom',
            },
            annotations: {
              title: 'The Container Registry database load balancer replica pool size is too low.',
              description: |||
                The size of the application-side DB load balancer replica pool in env {{ $labels.environment }} {{ $labels.stage }} stage has been lower than the number of available standby replicas for the last 5 minutes.
              |||,
              grafana_dashboard_id: 'registry-database/registry-database-detail',
              grafana_min_zoom_hours: '6',
              grafana_variables: 'environment,stage',
              grafana_datasource_id: tenant,
              runbook: 'registry/db-load-balancing/',
            },
          }),
        ],
      },
    ],
  }
