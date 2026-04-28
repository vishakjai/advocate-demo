local configFile = std.extVar('configFile');

local generateTest(index, testcase) =
  '(amtool config routes test --verify.receivers=%(receivers)s --config.file %(configFile)s %(labels)s >/dev/null) && echo "✔︎ %(name)s" || { echo "𐄂 Testcase #%(index)d %(name)s failed. Expected %(receivers)s got $(amtool config routes test --config.file %(configFile)s %(labels)s)"; exit 1; }' % {
    configFile: configFile,
    labels: std.join(' ', std.map(function(key) key + '=' + testcase.labels[key], std.objectFields(testcase.labels))),
    receivers: std.join(',', testcase.receivers),
    index: index,
    name: testcase.name,
  };

local generateTests(testcases) =
  std.join('\n', std.mapWithIndex(generateTest, testcases));

/**
 * This file contains a test of tests to ensure that out alert routing rules
 * work as we expect them too
 */
generateTests([
  {
    name: 'no labels',
    labels: {},
    receivers: [
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'no matching labels',
    labels: {
      __unknown: 'x',
    },
    receivers: [
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'pagerduty',
    labels: {
      env: 'gprd',
      pager: 'pagerduty',
    },
    receivers: [
      'incidentio',
      'production_slack_channel',
    ],
  },
  {
    name: 'production pagerduty and rules_domain=general',
    labels: {
      pager: 'pagerduty',
      rules_domain: 'general',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'slack_bridge-prod',
      'production_slack_channel',
    ],
  },
  {
    name: 'env=thanos, production pagerduty and rules_domain=general',
    labels: {
      pager: 'pagerduty',
      rules_domain: 'general',
      env: 'thanos',
    },
    receivers: [
      'incidentio',
      'slack_bridge-prod',
      'production_slack_channel',
    ],
  },
  {
    name: 'gstg pagerduty and rules_domain=general',
    labels: {
      pager: 'pagerduty',
      rules_domain: 'general',
      env: 'gstg',
    },
    receivers: [
      'slack_bridge-nonprod',
      'incidentio_gstg',
      'blackhole',
    ],
  },
  {
    name: 'pager=pagerduty, no env label',
    labels: {
      pager: 'pagerduty',
    },
    receivers: [
      'production_slack_channel',
    ],
  },

  {
    name: 'team=gitaly, pager=pagerduty, rules_domain=general',
    labels: {
      pager: 'pagerduty',
      rules_domain: 'general',
      team: 'gitaly',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'slack_bridge-prod',
      'team_gitaly_alerts_channel',
      'production_slack_channel',
    ],
  },
  {
    name: 'team alerts for non-prod productions should not go to team channels by default',
    labels: {
      pager: 'pagerduty',
      rules_domain: 'general',
      team: 'gitaly',
      env: 'gstg',
    },
    receivers: [
      'slack_bridge-nonprod',
      'incidentio_gstg',
      'blackhole',
    ],
  },
  {
    name: 'non-existent team',
    labels: {
      team: 'non_existent',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'issue alert, gstg environment',
    labels: {
      incident_project: 'gitlab.com/gitlab-com/gl-infra/infrastructure',
      env: 'gstg',
    },
    receivers: [
      'blackhole',
    ],
  },
  {
    name: 'issue alert, gprd environment',
    labels: {
      incident_project: 'gitlab.com/gitlab-com/gl-infra/infrastructure',
      env: 'gprd',
    },
    receivers: [
      'issue:gitlab.com/gitlab-com/gl-infra/infrastructure',
      'incidentio',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'issue alert, ops environment',
    labels: {
      incident_project: 'gitlab.com/gitlab-com/gl-infra/infrastructure',
      env: 'ops',
    },
    receivers: [
      'issue:gitlab.com/gitlab-com/gl-infra/infrastructure',
      'incidentio',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'paging issue alert, gprd environment',
    labels: {
      pager: 'pagerduty',
      incident_project: 'gitlab.com/gitlab-com/gl-infra/production',
      env: 'gprd',
    },
    receivers: [
      'issue:gitlab.com/gitlab-com/gl-infra/production',
      'incidentio',
      'production_slack_channel',
    ],
  },
  {
    name: 'issue alert, unknown project',
    labels: {
      incident_project: 'nothing',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'alertname="SnitchHeartBeat", env="ops"',
    labels: {
      alertname: 'SnitchHeartBeat',
      env: 'ops',
    },
    receivers: [
      'dead_mans_snitch_ops',
    ],
  },
  {
    name: 'alertname="SnitchHeartBeat", unknown environment',
    labels: {
      alertname: 'SnitchHeartBeat',
      env: 'space',
    },
    receivers: [
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'alertname="SnitchHeartBeat", no environment',
    labels: {
      alertname: 'SnitchHeartBeat',
    },
    receivers: [
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'pager=pagerduty, team=gitaly, env=gprd, slo_alert=yes, stage=cny, rules_domain=general',
    labels: {
      pager: 'pagerduty',
      rules_domain: 'general',
      team: 'gitaly',
      env: 'gprd',
      slo_alert: 'yes',
      stage: 'cny',
    },
    receivers: [
      'incidentio',
      'slack_bridge-prod',  // Slackline
      'team_gitaly_alerts_channel',  // Gitaly team alerts channel
      'production_slack_channel',  // production channel for pager alerts
    ],
  },
  {
    name: 'pager=pagerduty, team=gitaly, env=pre, slo_alert=yes, stage=cny, rules_domain=general',
    labels: {
      pager: 'pagerduty',
      rules_domain: 'general',
      team: 'gitaly',
      env: 'pre',
      slo_alert: 'yes',
      stage: 'cny',
    },
    receivers: [
      'blackhole',
    ],
  },
  {
    name: 'pager=pagerduty, team=runner_core, env=gprd',
    labels: {
      pager: 'pagerduty',
      team: 'runner_core',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'team_runner_core_alerts_channel',
      'production_slack_channel',
    ],
  },
  {
    name: 'pager=pagerduty, env=thanos',
    labels: {
      pager: 'pagerduty',
      env: 'thanos',
    },
    receivers: [
      'incidentio',
      'production_slack_channel',
    ],
  },
  {
    name: 'pager=pagerduty, team=gitlab-pages',
    labels: {
      pager: 'pagerduty',
      team: 'gitlab-pages',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'team_gitlab_pages_alerts_channel',
      'production_slack_channel',
    ],
  },
  {
    name: 'non pagerduty, team=gitlab-pages',
    labels: {
      team: 'gitlab-pages',
      severity: 's4',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'team_gitlab_pages_alerts_channel',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'pagerduty, product_stage_group=runner_core',
    labels: {
      pager: 'pagerduty',
      product_stage_group: 'runner_core',
      severity: 's1',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'team_runner_core_alerts_channel',
      'production_slack_channel',
    ],
  },
  {
    name: 'nonpagerduty, team=runner_core, product_stage_group=runner_core',
    labels: {
      rules_domain: 'general',
      product_stage_group: 'runner_core',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'slack_bridge-prod',
      'team_runner_core_alerts_channel',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'unknown product_stage_group: pagerduty product_stage_group=wombats',
    labels: {
      pager: 'pagerduty',
      severity: 's1',
      product_stage_group: 'wombats',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'production_slack_channel',
    ],
  },
  {
    name: 'gstg traffic anomaly service_ops_out_of_bounds_lower_5m alerts should go to blackhole',
    labels: {
      alertname: 'service_ops_out_of_bounds_lower_5m',
      rules_domain: 'general',
      env: 'gstg',
    },
    receivers: [
      'blackhole',
    ],
  },
  {
    name: 'gstg traffic anomaly service_ops_out_of_bounds_upper_5m alerts should go to blackhole',
    labels: {
      alertname: 'service_ops_out_of_bounds_upper_5m',
      rules_domain: 'general',
      env: 'gstg',
    },
    receivers: [
      'blackhole',
    ],
  },
  {
    name: 'gstg traffic_cessation alerts should go to blackhole',
    labels: {
      alert_class: 'traffic_cessation',
      rules_domain: 'general',
      env: 'gstg',
    },
    receivers: [
      'blackhole',
    ],
  },
  // Feature category tests.
  // These tests rely on the feature categories from https://gitlab.com/gitlab-com/www-gitlab-com/blob/master/data/stages.yml
  // After running ./scripts/update_stage_groups_feature_categories.rb, these may occassionally break,
  // as feature_categories are moved between different stage groups.
  {
    name: 'feature_category="runner_core" alerts should be routed to team_runner_core_alerts_channel',
    labels: {
      feature_category: 'runner_core',
      env: 'gprd',
    },
    receivers: [
      'incidentio',
      'team_runner_core_alerts_channel',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'pages, platform_insights team, gstg env -> platform_insights pagerduty, platform_insights slack',
    labels: {
      env: 'gstg',
      team: 'platform_insights',
      pager: 'platform_insights_pagerduty',
    },
    receivers: [
      'team_platform_insights_alerts_channel',
      'platform_insights_pagerduty',
    ],
  },
  {
    name: 'pages, platform_insights team, gprd env -> platform_insights pagerduty, platform_insights slack',
    labels: {
      env: 'gprd',
      team: 'platform_insights',
      pager: 'platform_insights_pagerduty',
    },
    receivers: [
      'incidentio',
      'team_platform_insights_alerts_channel',
      'platform_insights_pagerduty',
    ],
  },
  {
    name: 'platform_insights team, gstg env -> platform_insights slack',
    labels: {
      env: 'gstg',
      team: 'platform_insights',
    },
    receivers: [
      'team_platform_insights_alerts_channel',
      'blackhole',
    ],
  },
  {
    name: 'platform_insights team, gprd env -> platform_insights slack',
    labels: {
      env: 'gprd',
      team: 'platform_insights',
    },
    receivers: [
      'incidentio',
      'team_platform_insights_alerts_channel',
      // We are ok with #alerts channel getting notifications for services that
      // SREs are not responsible ATM.
      'prod_alerts_slack_channel',
    ],
  },
  // t4cc0re pointed out that this alert did not page
  // so we added a test case
  {
    name: 'Ext PVS alerts',
    labels: {
      alertname: 'ExtPvsServiceRunwayIngressApdexSLOViolation',
      aggregation: 'component',
      alert_class: 'slo_violation',
      alert_type: 'symptom',
      component: 'http',
      env: 'gprd',
      environment: 'gprd',
      feature_category: 'not_owned',
      monitor: 'global',
      pager: 'pagerduty',
      rules_domain: 'general',
      severity: 's2',
      sli_type: 'apdex',
      slo_alert: 'yes',
      stage: 'main',
      team: 'pipeline_validation',
      tier: 'sv',
      type: 'ext-pvs',
      user_impacting: 'yes',
      window: '6h',
    },
    receivers: [
      'incidentio',
      'slack_bridge-prod',
      'team_pipeline_validation_alerts_channel',
      'production_slack_channel',
    ],
  },
  {
    name: 'slo_alert=yes, env=gstg type=web should go to feed_alerts_staging and blackhole',
    labels: { env: 'gstg', slo_alert: 'yes', type: 'web' },
    receivers: [
      'feed_alerts_staging',
      'incidentio_gstg',
      'blackhole',
    ],
  },
  {
    name: 'slo_alert=yes, env=gstg type=web, aggregation=regional_component should go to blackhole',
    labels: { env: 'gstg', slo_alert: 'yes', type: 'web', aggregation: 'regional_component' },
    receivers: [
      'blackhole',
    ],
  },
  {
    name: 'slo_alert=yes, env=gprd, team=ai_framework should go to g_mlops-alerts',
    labels: { env: 'gprd', team: 'ai_framework' },
    receivers: [
      'incidentio',
      'team_ai_framework_alerts_channel',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'env=gprd, feature_category=code_suggestions should go to g_mlops-alerts',
    labels: { env: 'gprd', feature_category: 'code_suggestions' },
    receivers: [
      'incidentio',
      'team_ai_coding_alerts_channel',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'type=fleet should go to f_fleet_alerts',
    labels: {
      type: 'fleet',
    },
    receivers: [
      'fleet_alerts_slack_channel',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'tenant_type=cell should route to incidentio',
    labels: {
      tenant_type: 'cell',
      tenant: 'cell-us-east1-b',
    },
    receivers: [
      'incidentio',
      'prod_alerts_slack_channel',
    ],
  },
  {
    name: 'tenant_type=cell with pager=pagerduty should route to incidentio and production_slack',
    labels: {
      tenant_type: 'cell',
      tenant: 'cell-us-east1-b',
      pager: 'pagerduty',
    },
    receivers: [
      'incidentio',
      'production_slack_channel',
    ],
  },
  {
    name: 'sidekiq elasticsearch shard alerts should route to global_search slack and pagerduty',
    labels: {
      env: 'gprd',
      type: 'sidekiq',
      shard: 'elasticsearch',
      pager: 'pagerduty',
    },
    receivers: [
      'incidentio',
      'global_search_slack_channel',
      'production_slack_channel',
    ],
  },
])
