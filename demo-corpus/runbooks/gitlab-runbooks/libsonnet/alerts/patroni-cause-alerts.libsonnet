local alerts = import 'alerts/alerts.libsonnet';
local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local aggregationLabelsForPrimary = ['environment', 'tier', 'type', 'fqdn'];
local aggregationLabelsForReplicas = ['environment', 'tier', 'type'];
local selector = {
  tier: 'db',
  shard: 'default',
  type: [
    { nre: '.*archive' },
    { nre: '.*delayed' },
  ],
};

local alertExpr(aggregationLabels, selectorNumerator, selectorDenominator, replica, threshold, window='5m', extraSelector) =
  local aggregationLabelsWithRelName = aggregationLabels + ['relname'];

  |||
    (
      sum by (%(aggregationLabelsWithRelName)s) (
        rate(pg_stat_user_tables_idx_tup_fetch{%(selectorNumerator)s}[%(window)s])
        and on(job, instance)
        pg_replication_is_replica == %(replica)s
      )
      / ignoring(relname) group_left()
        sum by (%(aggregationLabels)s) (
          rate(pg_stat_user_tables_idx_tup_fetch{%(selectorDenominator)s}[%(window)s])
          and on(job, instance)
          pg_replication_is_replica == %(replica)s
      )
    ) > %(threshold)g
  ||| % {
    aggregationLabelsWithRelName: aggregations.serialize(aggregationLabelsWithRelName),
    aggregationLabels: aggregations.serialize(aggregationLabels),
    selectorNumerator: selectors.serializeHash(selectorNumerator + extraSelector),
    selectorDenominator: selectors.serializeHash(selectorDenominator + extraSelector),
    replica: if replica then '1' else '0',
    window: window,
    threshold: threshold,
  };

local hotspotTupleAlert(alertName, periodFor, warning, replica, extraSelector, tenant=null) =
  local threshold = 0.5;  // 50%
  local aggregationLabels = if replica then aggregationLabelsForReplicas else aggregationLabelsForPrimary;

  local elasticFilters = [
    matching.matchFilter('json.sql', '{{$labels.relname}}'),
  ] + (
    if replica then
      []
    else
      [matching.matchFilter('json.fqdn', '{{$labels.fqdn}}')]
  );


  local formatConfig = {
    postgresLocation: if replica then 'postgres replicas' else 'primary `{{ $labels.fqdn }}`',
    thresholdPercent: threshold * 100,
    kibanaUrl: elasticsearchLinks.buildElasticDiscoverSearchQueryURL('postgres', elasticFilters, timeRange=''),
  };

  alerts.processAlertRule({
    alert: alertName,
    expr: alertExpr(
      aggregationLabels=aggregationLabels,
      selectorNumerator=selector,
      selectorDenominator=selector,
      replica=replica,
      threshold=threshold,
      extraSelector=extraSelector
    ),
    'for': periodFor,
    labels: {
      severity: if warning then 's4' else 's1',
      alert_type: 'cause',
      [if !warning then 'pager']: 'pagerduty',
    },
    annotations: {
      title: 'Hot spot tuple fetches on the postgres %(postgresLocation)s in the `{{ $labels.relname }}` table, `{{ $labels.relname }}`.' % formatConfig,
      description: |||
        More than %(thresholdPercent)g%% of all tuple fetches on postgres %(postgresLocation)s are for a single table.

        This may indicate that the query optimizer is using incorrect statistics to execute a query.

        This could be due to vacuum and analyze commands (issued either automatically or manually) against this table or closely related table.
        As a new step, check which tables were analyzed and vacuumed immediately prior to this incident.

        <%(kibanaUrl)s|postgres slowlog in Kibana>

        Previous incidents of this type include <https://gitlab.com/gitlab-com/gl-infra/production/-/issues/2885> and
        <https://gitlab.com/gitlab-com/gl-infra/production/-/issues/3875>.
      ||| % formatConfig,
      grafana_dashboard_id: if replica then 'alerts-pg_user_tables_replica/alerts-pg-user-table-alerts-replicas' else 'alerts-pg_user_tables_primary/alerts-pg-user-table-alerts-primary',
      grafana_min_zoom_hours: '6',
      grafana_panel_id: '2',
      grafana_variables: aggregations.serialize(aggregationLabels + ['relname']),
      grafana_datasource_id: tenant,
      runbook: 'patroni/rails-sql-apdex-slow/',
    },
  });

local rules(extraSelector={}, tenant=null) = {
  groups: [
    {
      name: 'patroni_cause_alerts',
      rules: [
        hotspotTupleAlert(
          'PostgreSQL_HotSpotTupleFetchingPrimary',
          '10m',
          warning=true,
          replica=false,
          extraSelector=extraSelector,
          tenant=tenant,
        ),
        hotspotTupleAlert(
          'PostgreSQL_HotSpotTupleFetchingReplicas',
          '10m',
          warning=true,
          replica=true,
          extraSelector=extraSelector,
          tenant=tenant,
        ),

        // Special alert for Access Group
        // See https://gitlab.com/groups/gitlab-org/-/epics/3343#note_651528817
        alerts.processAlertRule({
          alert: 'PostgreSQLAccessGroupTupleFetchesWarningTrigger',
          expr: alertExpr(
            aggregationLabels=aggregationLabelsForPrimary,
            selectorNumerator=selector { relname: 'project_authorizations' },
            selectorDenominator=selector,
            replica=false,
            threshold=0.05,
            window='1d',
            extraSelector=extraSelector
          ),
          'for': '1h',
          labels: {
            team: 'authentication',
            severity: 's4',
            alert_type: 'cause',
          },
          annotations: {
            title: 'Average fetches on the postgres primary in the project_authorizations table exceeds 5% of total',
            description: |||
              More than 5% of all tuple fetches on the postgres primary are for the `project_authorizations` table.

              This work was previously addressed through the epic https://gitlab.com/groups/gitlab-org/-/epics/3343#note_652970688.

              The Authentication and authorization team should work to understand why this is happening and look to address the problem.
            |||,
            grafana_dashboard_id: 'alerts-pg_user_tables_primary/alerts-pg-user-table-alerts-primary',
            grafana_min_zoom_hours: '24',
            grafana_panel_id: '2',
            grafana_variables: aggregations.serialize(aggregationLabelsForPrimary + ['relname']),
            grafana_datasource_id: tenant,
            runbook: 'patroni/rails-sql-apdex-slow/',
          },
        }),

        // Subtransactions wait events alert
        alerts.processAlertRule({
          alert: 'PatroniSubtransControlLocksDetected',
          expr: |||
            sum by (environment) (
              sum_over_time(pg_stat_activity_marginalia_sampler_active_count{%(selector)s}[10m])
            ) > 10
          ||| % {
            selector: selectors.serializeHash({ wait_event: { re: '[Ss]ubtrans.*' } } + extraSelector),
          },
          'for': '5m',
          labels: {
            team: 'subtransaction_troubleshooting',
            severity: 's3',
            alert_type: 'cause',
          },
          annotations: {
            title: 'Subtransactions wait events have been detected in the database in the last 5 minutes',
            description: |||
              Wait events related to subtransactions locking have been detected in the database in the last 5 minutes.

              This can eventually saturate entire database cluster if this situation continues for a longer period of time.
            |||,
            grafana_datasource_id: tenant,
            runbook: 'patroni/postgresql-subtransactions',
          },
        }),

        // Long running transaction alert
        alerts.processAlertRule({
          alert: 'PatroniLongRunningTransactionDetected',
          expr: |||
            topk by (environment, env, type, stage, shard) (1,
              max by (environment, env, type, stage, shard, application, endpoint, fqdn) (
                pg_stat_activity_marginalia_sampler_max_tx_age_in_seconds{%(selector)s}
              )
              > 540
            )
          ||| % {
            selector: selectors.serializeHash(selector {
              command: [
                { ne: 'autovacuum' },
                { nre: '(?i:VACUUM)' },
                { nre: '(?i:CREATE)' },
                { nre: '(?i:ANALYZE)' },
                { nre: '(?i:REINDEX)' },
                { nre: '(?i:ALTER)' },
                { nre: '(?i:DROP)' },
              ],
            } + extraSelector),
          },
          'for': '1m',
          labels: {
            severity: 's3',
            alert_type: 'cause',
            team: 'database_operations',
          },
          annotations: {
            title: 'Transactions detected that have been running on `{{ $labels.fqdn }}` for more than 10m',
            description: |||
              Endpoint `{{ $labels.endpoint }}` on `{{ $labels.application }}` is executing a transaction that has been running
              for more than 10m. This could lead to dead-tuples and performance degradation in our Patroni fleet.

              Ideally, no transaction should remain open for more than a few seconds.
            |||,
            grafana_dashboard_id: 'alerts-long_running_transactions/alerts-long-running-transactions',
            grafana_min_zoom_hours: '6',
            grafana_variables: 'environment',
            grafana_datasource_id: tenant,
            runbook: 'patroni/alerts/PatroniLongRunningTransactionDetected/',
          },
        }),
      ],
    },
  ],
};

rules
