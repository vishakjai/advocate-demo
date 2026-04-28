local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;

metricsCatalog.serviceDefinition(
  {
    type: 'secrets-manager',
    featureCategory: 'secrets_management',
    tier: 'sv',
    tags: ['golang'],
    nodeLevelMonitoring: false,

    serviceLevelIndicators: {
      openbao_requests: {
        description: 'Non-login requests to OpenBao API for secrets manager operations.',
        trafficCessationAlertConfig: false,
        userImpacting: false,
        severity: 's4',
        requestRate: rateMetric(
          counter='openbao_core_handle_request_count',
        ),
        significantLabels: [],
      },
    },
  }
)
