local alerts = import 'alerts/alerts.libsonnet';
local saturationRules = import 'servicemetrics/saturation_rules.libsonnet';
local serviceAlertsGenerator = import 'slo-alerts/service-alerts-generator.libsonnet';

local alertDescriptors(aggregationSets, minimumSamplesForMonitoring, minimumSamplesForTrafficCessation) = [{
  predicate: function(service, sli) !sli.shardLevelMonitoring,
  alertSuffix: '',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service (`{{ $labels.stage }}` stage)',
  alertExtraDetail: null,
  aggregationSet: aggregationSets.componentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForMonitoring,
  alertForDuration: null,  // Use default for window...
  trafficCessationSelector: null,
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}, {
  predicate: function(service, sli) sli.shardLevelMonitoring,
  alertSuffix: 'SingleShard',
  alertTitleTemplate: 'The %(sliName)s SLI of the %(serviceType)s service on shard `{{ $labels.shard }}`',
  alertExtraDetail: 'Since the `{{ $labels.type }}` service is not fully redundant, SLI violations on a single shard may represent a user-impacting service degradation.',
  aggregationSet: aggregationSets.shardComponentSLIs,
  minimumSamplesForMonitoring: minimumSamplesForMonitoring,
  alertForDuration: null,
  trafficCessationSelector: {},
  minimumSamplesForTrafficCessation: minimumSamplesForTrafficCessation,
}];

local annotations(description='') = {
  runbook: 'hosted-runners/',
  description: description,
};

local customRules() =
  local rules = [
    {
      alert: 'HostedRunnersServiceRunnerManagerDownSingleShard',
      expr: 'gitlab_component_shard_ops:rate_5m{component="api_requests",type="hosted-runners"} == 0',
      'for': '5m',
      labels: {
        severity: 's1',
        alert_type: 'cause',
      },
      annotations: annotations(
        description='The runner manager in HostedRunnersService has disconnected for a single shard. This may impact job scheduling for that shard.',
      ),
    },
  ];

  [
    {
      interval: '1m',
      name: 'Custom Alerts: hosted-runners',
      rules+: alerts.processAlertRules(rules),
    },
  ];


local alertsForServices(config) =
  local metricsConfig = config.gitlabMetricsConfig;
  local minimumSamplesForMonitoring = config.minimumSamplesForMonitoring;
  local minimumSamplesForTrafficCessation = config.minimumSamplesForTrafficCessation;

  local serviceAlerts = std.foldl(
                          function(memo, service)
                            memo + serviceAlertsGenerator(
                              service,
                              alertDescriptors(
                                metricsConfig.aggregationSets,
                                minimumSamplesForMonitoring,
                                minimumSamplesForTrafficCessation
                              )
                            ),
                          metricsConfig.monitoredServices,
                          []
                        )
                        + saturationRules.generateSaturationAlertsGroup(
                          evaluation='both',
                          saturationResources=config.gitlabMetricsConfig.saturationMonitoring,
                          thanosSelfMonitoring=false,
                          extraSelector={}
                        );

  serviceAlerts + customRules();

alertsForServices
