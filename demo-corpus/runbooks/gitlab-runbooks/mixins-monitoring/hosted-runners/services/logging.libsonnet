local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

local rateMetric = metricsCatalog.rateMetric;
local customRateQuery = metricsCatalog.customRateQuery;
local errorCounterApdex = metricsCatalog.errorCounterApdex;
local histogramApdex = metricsCatalog.histogramApdex;

local fluentdSelector = {
  job: 'hosted-runners-fluentd-agent',
  shard: { re: '.*' },
  plugin: 's3',
};

local replicationSelector = {
  rule_id: 'replication-rule-hosted-runner',
};

metricsCatalog.serviceDefinition({
  type: 'hosted-runners-logging',
  tier: 'inf',

  serviceIsStageless: true,
  regional: false,

  shardLevelMonitoring: true,
  disableOpsRatePrediction: false,
  shard: [],

  provisioning: {
    // Set it to false for now as we do not have node metrics.
    vms: false,
    kubernetes: false,
  },

  monitoringThresholds: {
    errorRatio: 0.999,
  },

  serviceLevelIndicators: {
    usage_logs: {
      userImpacting: false,
      featureCategory: 'not_owned',
      severity: 's1',
      serviceAggregation: true,
      // Setting this to false as this metric may not be continuous due to runner inactivity.
      // Most important error here for now is the number of errors.
      trafficCessationAlertConfig: false,
      shardLevelMonitoring: true,
      description: |||
        This log SLI represents the total number of errors encountered by Fluentd while writing
        logs to S3 destination.

        For more information, see: https://runbooks.gitlab-static.net/hosted-runners/logging_service_usage_logs_error/index.html
      |||,

      requestRate: rateMetric(
        counter='fluentd_output_status_write_count',
        selector=fluentdSelector,
      ),

      errorRate: rateMetric(
        counter='fluentd_output_status_num_errors',
        selector=fluentdSelector,
      ),

      significantLabels: [],
    },

    usage_replication: {
      userImpacting: false,
      featureCategory: 'not_owned',
      severity: 's1',
      serviceAggregation: false,
      trafficCessationAlertConfig: false,
      shardLevelMonitoring: false,
      description: |||
        This log SLI represents the total number of errors encountered by S3 replicating objects
        to the central S3 destination.

        For more information, see: https://runbooks.gitlab-static.net/hosted-runners/usage_replication_error/index.html
      |||,

      requestRate: customRateQuery(|||
        avg_over_time(aws_s3_operations_pending_replication_sum[%(burnRate)s])
      |||),

      errorRate: customRateQuery(|||
        avg_over_time(aws_s3_operations_failed_replication_sum[%(burnRate)s])
      |||),

      significantLabels: [],
    },
  },
})
