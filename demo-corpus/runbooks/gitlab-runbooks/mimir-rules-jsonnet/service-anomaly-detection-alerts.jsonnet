local monitoredServices = (import 'gitlab-metrics-config.libsonnet').monitoredServices;
local selectors = import 'promql/selectors.libsonnet';
local alerts = import 'alerts/alerts.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local serviceAnomalyDetectionAlerts = import 'alerts/service-anomaly-detection-alerts.libsonnet';

local servicesWithOpsRatePrediction = std.filter(
  function(service) !service.disableOpsRatePrediction,
  monitoredServices
);

local outputPromYaml(groups) =
  std.manifestYamlDoc({
    groups: groups,
  });

local fileForService(service, extraSelector, _extraArgs, tenant) =
  local selector = selectors.merge(extraSelector, { type: service.type });
  {
    'service-anomaly-detection-alerts': outputPromYaml(
      [
        {
          name: '%s - service_ops_anomaly_detection' % service.type,
          rules: alerts.processAlertRules(
            serviceAnomalyDetectionAlerts(
              selector,
              'service_ops',
              'gitlab_service_ops',
              'disable_ops_rate_prediction',
              'Anomaly detection: The `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is receiving more requests than normal',
              |||
                The `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is receiving more requests than normal.
                This is often caused by user generated traffic, sometimes abuse. It can also be cause by application changes that lead to higher operations rates or from retries in the event of errors. Check the abuse reporting watches in Elastic, ELK for possible abuse, error rates (possibly on upstream services) for root cause.
              |||,
              'https://gitlab.com/gitlab-com/runbooks/blob/master/docs/monitoring/definition-service-ops-rate.md',
              'gitlab_component_ops',
              'Anomaly detection: The `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is receiving fewer requests than normal',
              |||
                The `{{ $labels.type }}` service (`{{ $labels.stage }}` stage) is receiving fewer requests than normal.
                This is often caused by a failure in an upstream service - for example, an upstream load balancer rejected all incoming traffic. In many cases, this is as serious or more serious than a traffic spike. Check upstream services for errors that may be leading to traffic flow issues in downstream services.
              |||,
              'service-$type-ops-rate',
              tenant
            )
          ),
        },
      ],
    ),
  };

std.foldl(
  function(memo, service)
    memo + separateMimirRecordingFiles(
      fileForService,
      service,
    ),
  servicesWithOpsRatePrediction,
  {}
)
