local gitlabMetricsConfig = import 'gitlab-metrics-config.libsonnet';
local alertsForServices = import 'lib/alerts-generator.libsonnet';
local aggregationRulesForServices = import 'lib/rules-generator.libsonnet';
local saturationResource = import 'lib/saturation.libsonnet';
local hostedRunnerserviceDefinition = import 'lib/service.libsonnet';
local templates = import 'lib/templates.libsonnet';

{
  _config+:: {
    gitlabMetricsConfig+:: gitlabMetricsConfig,

    prometheusDatasource: 'Global',

    // The rate interval for dashboard.
    rateInterval: '5m',

    // The dashboard name used when building dashboards.
    dashboardName: 'Hosted Runners',

    // Tags for dashboards.
    dashboardTags: ['hosted-runners', 'dedicated'],

    // Matches all shards in the selected Stack(s), optionally narrowed to a
    // specific deployment color via $shard.
    runnerNameSelector: 'shard=~".+-(${stack:pipe})", shard=~"$shard"',

    // Query selector based on the hosted runner job
    runnerJobSelector: 'job="hosted-runners-prometheus-agent"',

    fluentdPluginSelector: 'shard=~".+-(${stack:pipe})", shard=~"$shard", plugin=~"$plugin"',

    replicationSelector: 'rule_id="replication-rule-hosted-runner"',

    minimumSamplesForMonitoring: 50,

    minimumSamplesForTrafficCessation: 300,

    templates:: templates,
  },

  prometheusRulesGroups+:: aggregationRulesForServices(self._config),

  prometheusAlertsGroups+:: alertsForServices(self._config),

}
