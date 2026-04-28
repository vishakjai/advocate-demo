local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

local rateMetric = metricsCatalog.rateMetric;
local errorCounterApdex = metricsCatalog.errorCounterApdex;
local histogramApdex = metricsCatalog.histogramApdex;

local baseSelector = {
  job: 'hosted-runners-prometheus-agent',
};

metricsCatalog.serviceDefinition({
  type: 'hosted-runners',
  tier: 'inf',

  serviceIsStageless: true,
  regional: false,

  shardLevelMonitoring: true,
  shard: [],

  provisioning: {
    // Set it to false for now as we do not have node metrics for now.
    vms: false,
    kubernetes: false,
  },

  monitoringThresholds: {
    apdexScore: 0.97,
    errorRatio: 0.999,
  },

  serviceLevelIndicators: {
    api_requests: {
      userImpacting: true,
      shardLevelMonitoring: true,
      serviceAggregation: false,
      severity: 's1',
      description: |||
        This SLI monitors the hosted runner api requests.

        Requests marked as failing with status 5xx are considered to be in error.

        For more information, see: https://runbooks.gitlab-static.net/hosted-runners/api_requests_error_violation/index.html
      |||,

      requestRate: rateMetric(
        counter='gitlab_runner_api_request_statuses_total',
        selector=baseSelector { shard: { re: '.*' } },
      ),

      errorRate: rateMetric(
        counter='gitlab_runner_api_request_statuses_total',
        selector=baseSelector {
          status: { re: '5..', ne: '409' },
          shard: { re: '.*' },
        },
      ),

      significantLabels: ['status', 'endpoint'],
    },

    ci_runner_jobs: {
      userImpacting: true,
      trafficCessationAlertConfig: false,
      shardLevelMonitoring: true,
      severity: 's1',
      description: |||
        This SLI monitors the hosted runner jobs handling. Each job is an operation.

        Jobs marked as failing with runner system failures are considered to be in error.

        For more information, see: https://runbooks.gitlab.com/hosted-runners/#alerts
      |||,

      apdex: errorCounterApdex(
        errorRateMetric='gitlab_runner_acceptable_job_queuing_duration_exceeded_total',
        operationRateMetric='gitlab_runner_jobs_total',
        selector=baseSelector { shard: { re: '.*' } },
      ),

      requestRate: rateMetric(
        counter='gitlab_runner_jobs_total',
        selector=baseSelector { shard: { re: '.*' } },
      ),

      errorRate: rateMetric(
        counter='gitlab_runner_failed_jobs_total',
        selector=baseSelector {
          failure_reason: 'runner_system_failure',
          shard: { re: '.*' },
        },
      ),

      monitoringThresholds+: {
        errorRatio: 0.98,
      },

      significantLabels: [],
    },

    queuing_queries_duration: {
      userImpacting: false,
      trafficCessationAlertConfig: false,
      serviceAggregation: false,
      severity: 's1',
      description: |||
        This SLI monitors the queuing queries duration. Everything above 1
        second is considered to be unexpected and needs investigation.

        These database queries are executed in the Rails application when a
        runner requests a new build to process in `POST /api/v4/jobs/request`.

        For more information, see: https://runbooks.gitlab.com/hosted-runners/#alerts
      |||,

      apdex: histogramApdex(
        histogram='gitlab_runner_job_queue_duration_seconds_bucket',
        satisfiedThreshold=0.5,
      ),

      requestRate: rateMetric(
        counter='gitlab_runner_job_queue_duration_seconds_count',
      ),

      emittedBy: ['api'],

      monitoringThresholds+: {
        apdexScore: 0.999,
      },

      significantLabels: ['runner_type'],
    },

    polling: {
      userImpacting: true,
      trafficCessationAlertConfig: false,
      serviceAggregation: false,
      severity: 's1',
      description: |||
        This SLI monitors job polling operations from runners, via
        Workhorse's `/api/v4/jobs/request` route.

        5xx responses are considered to be errors, and could indicate postgres timeouts (after 15s) on the main query
        used in assigning jobs to runners.

        For more information, see: https://runbooks.gitlab.com/hosted-runners/#alerts
      |||,

      local baseSelector = {
        route: '^/api/v4/jobs/request\\\\z',
      },

      requestRate: rateMetric(
        counter='gitlab_workhorse_http_requests_total',
        selector=baseSelector,
      ),

      errorRate: rateMetric(
        counter='gitlab_workhorse_http_requests_total',
        selector=baseSelector { code: { re: '5..' } },
      ),

      emittedBy: ['api', 'ops-gitlab-net', 'web'],

      significantLabels: ['code'],

    },

    pending_builds: {
      userImpacting: true,
      trafficCessationAlertConfig: false,
      shardLevelMonitoring: true,
      severity: 's3',  // Don't page SREs for this SLI
      description: |||
        This SLI monitors pending job from runners.

        Jobs that are waiting more than 300s are considered as a error and impact
        service apdex.

        For more information, see: https://runbooks.gitlab.com/hosted-runners/#alerts
      |||,

      apdex: histogramApdex(
        histogram='gitlab_runner_job_queue_duration_seconds_bucket',
        satisfiedThreshold=120,
        metricsFormat='migrating',
        selector=baseSelector { shard: { re: '.*' } }
      ),

      requestRate: rateMetric(
        counter='gitlab_runner_job_queue_duration_seconds_count',
        selector=baseSelector { shard: { re: '.*' } }
      ),

      significantLabels: [],
    },

  },
})
