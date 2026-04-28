local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local histogramApdex = metricsCatalog.histogramApdex;

metricsCatalog.serviceDefinition({
  type: 'mailgun',
  tier: 'sv',
  tenants: ['gitlab-ops'],

  serviceIsStageless: true,
  monitoringThresholds: {
    errorRatio: 0.9,
  },
  provisioning: {
    kubernetes: false,
    vms: false,
  },
  serviceLevelIndicators: {
    mail_delivery: {
      userImpacting: true,
      severity: 's3',
      featureCategory: 'not_owned',
      team: 'sre_reliability',
      requestRate: rateMetric('mailgun_delivery_accepted_total'),
      errorRate: rateMetric('mailgun_delivery_errors_total'),
      apdex: histogramApdex('mailgun_delivery_time_seconds_bucket', satisfiedThreshold=60, metricsFormat='migrating'),
      significantLabels: ['delivery_status_code'],
    },
  },
  skippedMaturityCriteria: {
    'Service exists in the dependency graph': 'Mailgun is a vendor',
    'Structured logs available in Kibana': 'Mailgun is a vendor',
  },
})
