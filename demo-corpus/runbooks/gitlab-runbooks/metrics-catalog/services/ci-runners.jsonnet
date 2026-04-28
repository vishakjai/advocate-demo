local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local errorCounterApdex = metricsCatalog.errorCounterApdex;
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local haproxyComponents = import './lib/haproxy_components.libsonnet';
local dependOnRedisSidekiq = import 'inhibit-rules/depend_on_redis_sidekiq.libsonnet';
local ciRunnersHelpers = import './lib/ci-runners-helpers.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'ci-runners',
  tier: 'runners',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-ops', 'gitlab-pre'],
  shards: ciRunnersHelpers.shards,
  monitoring: {
    shard: { enabled: true },
  },
  contractualThresholds: {
    apdexRatio: 0.95,
    errorRatio: 0.05,
  },
  monitoringThresholds: {
    apdexScore: 0.97,
    errorRatio: 0.999,
  },
  otherThresholds: {
    mtbf: {
      apdexScore: 0.985,
      errorRatio: 0.9999,
    },
  },
  serviceDependencies: {
    api: true,
  },
  serviceLevelIndicators: {
    loadbalancer: haproxyComponents.haproxyHTTPLoadBalancer(
      userImpacting=true,
      featureCategory='hosted_runners',
      selector={ type: 'ci' },
      stageMappings={
        main: { backends: ['https_git', 'api', 'ci_gateway_catch_all'], toolingLinks: [] },
      },
      dependsOn=dependOnRedisSidekiq.railsClientComponents,
    ) { shardLevelMonitoring: false },

    polling: {
      userImpacting: true,
      featureCategory: 'hosted_runners',
      shardLevelMonitoring: false,
      description: |||
        This SLI monitors job polling operations from runners, via
        Workhorse's `/api/v4/jobs/request` route.

        5xx responses are considered to be errors, and could indicate postgres timeouts (after 15s) on the main query
        used in assigning jobs to runners.
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

      emittedBy: ['api', 'ops-gitlab-net', 'web', 'ci-jobs-api'],

      significantLabels: ['code'],

      toolingLinks: [
        toolingLinks.kibana(
          title='Workhorse',
          index='workhorse',
          matches={ 'json.uri.keyword': '/api/v4/jobs/request' },
          includeMatchersForPrometheusSelector=false,

        ),
        toolingLinks.kibana(
          title='Postgres Slowlog',
          index='postgres',
          matches={ 'json.endpoint_id.keyword': 'POST /api/:version/jobs/request' },
          includeMatchersForPrometheusSelector=false
        ),
      ],
    },

    saas_linux_runner_image_pull_failures: {
      shardLevelMonitoring: false,
      serviceAggregation: false,
      monitoringThresholds+: {
        errorRatio: 0.99,
      },

      userImpacting: true,
      featureCategory: 'hosted_runners',
      description: |||
        This SLI monitors the image pulling failures on SaaS runner.
      |||,

      requestRate: rateMetric(
        counter='gitlab_runner_jobs_total',
        selector={
          job: { oneOf: ['runners-manager', 'scrapeConfig/monitoring/prometheus-agent-runner'] },
          type: 'ci-runners',
          shard: { oneOf: ['shared-gitlab-org', 'private', 'saas-linux-.*'] },
        },
      ),

      errorRate: rateMetric(
        counter='gitlab_runner_failed_jobs_total',
        selector={
          job: { oneOf: ['runners-manager', 'scrapeConfig/monitoring/prometheus-agent-runner'] },
          type: 'ci-runners',
          shard: { oneOf: ['shared-gitlab-org', 'private', 'saas-linux-.*'] },
          failure_reason: 'image_pull_failure',
        },
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='CI Runners', index='runners', slowRequestSeconds=60),
      ],
    },

    queuing_queries_duration: {
      userImpacting: false,
      shardLevelMonitoring: false,
      featureCategory: 'continuous_integration',
      team: 'pipeline_execution',
      description: |||
        This SLI monitors the queuing queries duration. Everything above 1
        second is considered to be unexpected and needs investigation.

        These database queries are executed in the Rails application when a
        runner requests a new build to process in `POST /api/v4/jobs/request`.
      |||,

      apdex: histogramApdex(
        histogram='gitlab_ci_queue_retrieval_duration_seconds_bucket',
        satisfiedThreshold=0.5,
      ),

      requestRate: rateMetric(
        counter='gitlab_ci_queue_retrieval_duration_seconds_count',
      ),

      emittedBy: ['api', 'ci-jobs-api'],

      monitoringThresholds+: {
        apdexScore: 0.91,
      },

      significantLabels: ['runner_type'],
      toolingLinks: [],
    },

    // Trace archive jobs do not mark themselves as failed
    // when a job fails, instead they increment the job_trace_archive_failed_total counter
    // For this reason, our normal Sidekiq job monitoring doesn't alert us to these failures.
    // Instead, track this as a component of the CI service
    // https://gitlab.com/gitlab-org/gitlab/blob/master/app/services/ci/archive_trace_service.rb
    trace_archiving_ci_jobs: {
      userImpacting: true,
      shardLevelMonitoring: false,
      featureCategory: 'continuous_integration',
      description: |||
        This SLI monitors CI job archiving, via Sidekiq jobs.
      |||,

      requestRate: rateMetric(
        counter='gitlab_sli_sidekiq_execution_total',
        selector={ worker: 'Ci::ArchiveTraceWorker' }
      ),

      errorRate: rateMetric(
        counter='job_trace_archive_failed_total',
      ),

      emittedBy: ['ops-gitlab-net', 'sidekiq'],

      significantLabels: [],

      toolingLinks: [
        toolingLinks.grafana(title='ArchiveTraceWorker Detail', dashboardUid='sidekiq-queue-detail', vars={ queue: 'pipeline_background:ci_archive_trace' }),
        toolingLinks.kibana(
          title='Sidekiq ArchiveTraceWorker',
          index='sidekiq',
          matches={ 'json.class.keyword': 'Ci::ArchiveTraceWorker' }
        ),
      ],
    },

    ci_runner_jobs: {
      userImpacting: true,
      featureCategory: 'hosted_runners',
      shardLevelMonitoring: true,
      description: |||
        This SLI monitors the SaaS runner jobs handling. Each job is an operation.

        Apdex uses queueing latencies. If shard is for instance runners on GitLab.com, it counts
        jobs which are considered to be fair-usage (less than 5 concurrently running jobs from
        a project on instance runners).

        Jobs marked as failing with runner system failures are considered to be in error.
      |||,

      apdex: errorCounterApdex(
        errorRateMetric='gitlab_runner_acceptable_job_queuing_duration_exceeded_total',
        operationRateMetric='gitlab_runner_jobs_total',
        selector={
          job: { oneOf: ['runners-manager', 'scrapeConfig/monitoring/prometheus-agent-runner'] },
          type: 'ci-runners',
          shard: { oneOf: ['shared-gitlab-org', 'private', 'saas-.*', 'windows-shared'], noneOf: ['saas-macos-staging'] },
        },
      ),

      requestRate: rateMetric(
        counter='gitlab_runner_jobs_total',
        selector={
          job: { oneOf: ['runners-manager', 'scrapeConfig/monitoring/prometheus-agent-runner'] },
          type: 'ci-runners',
          shard: { oneOf: ['shared-gitlab-org', 'private', 'saas-.*', 'windows-shared'], noneOf: ['saas-macos-staging'] },
        },
      ),

      errorRate: rateMetric(
        counter='gitlab_runner_failed_jobs_total',
        selector={
          job: { oneOf: ['runners-manager', 'scrapeConfig/monitoring/prometheus-agent-runner'] },
          type: 'ci-runners',
          shard: { oneOf: ['shared-gitlab-org', 'private', 'saas-.*', 'windows-shared'], noneOf: ['saas-macos-staging'] },
          failure_reason: 'runner_system_failure',
        },
      ),

      significantLabels: [],

      toolingLinks: [
        toolingLinks.kibana(title='CI Runners', index='runners', slowRequestSeconds=60),
      ],
    },

    local ciRunnerJobs = self.ci_runner_jobs,
    qa_runner_jobs: ciRunnerJobs {
      userImpacting: false,
      shardLevelMonitoring: false,
      serviceAggregation: false,
      featureCategory: 'not_owned',
      team: 'test_tools_infrastructure',

      // These runners are only used internally so this shouldn't page the EoC
      // directly. The owning team will escalate when needed.
      severity: 's4',

      description+: |||
        This SLI only focuses on the qa-runners and saas-macos-staging shards, which are excluded from the
        main SLI because they are not user impacting.
      |||,

      local qaRunnersSelector = { shard: { oneOf: ['qa-runners', 'saas-macos-staging'] } },

      apdex: errorCounterApdex(
        errorRateMetric=ciRunnerJobs.apdex.errorRateMetric,
        operationRateMetric=ciRunnerJobs.apdex.operationRateMetric,
        selector=ciRunnerJobs.apdex.selector + qaRunnersSelector,
      ),

      requestRate: rateMetric(
        counter=ciRunnerJobs.requestRate.counter,
        selector=ciRunnerJobs.requestRate.selector + qaRunnersSelector,
      ),

      errorRate: rateMetric(
        counter=ciRunnerJobs.errorRate.counter,
        selector=ciRunnerJobs.errorRate.selector + qaRunnersSelector,
      ),

      monitoringThresholds+: {
        apdexScore: 0.90,
        errorRatio: 0.95,
      },
    },

    machine_creation: {
      // Experimental for now: records metrics and dashboards, no alerting.
      // To enable alerting, drop `experimental` and set a `monitoringThresholds+.errorRatio`
      // once we've watched a steady-state baseline.
      experimental: true,
      serviceAggregation: false,  // required with `experimental: true`
      userImpacting: true,
      featureCategory: 'hosted_runners',
      shardLevelMonitoring: true,
      description: |||
        Success rate of docker-machine VM creations by runner managers.

        Each docker-machine `Create()` call on the google driver increments
        `gitlab_runner_autoscaling_actions_total{action="created"|"creation-failed"}`.
        Sustained elevated failure is an upstream signal that job queues will
        back up regardless of the job-level error rate — an orthogonal signal
        to the `ci_runner_jobs` apdex, which only trips once the queue has
        already grown.
      |||,

      requestRate: rateMetric(
        counter='gitlab_runner_autoscaling_actions_total',
        selector={
          action: { oneOf: ['created', 'creation-failed'] },
          shard: { oneOf: ['shared-gitlab-org', 'private', 'saas-linux-.*'] },
        },
      ),

      errorRate: rateMetric(
        counter='gitlab_runner_autoscaling_actions_total',
        selector={
          action: 'creation-failed',
          shard: { oneOf: ['shared-gitlab-org', 'private', 'saas-linux-.*'] },
        },
      ),

      significantLabels: ['zone'],

      toolingLinks: [
        toolingLinks.kibana(
          title='Machine creation errors',
          index='runners',
          matches={ 'json.msg.keyword': 'Error creating machine' },
        ),
      ],
    },

    runner_api_requests: {
      userImpacting: true,
      featureCategory: 'hosted_runners',
      shardLevelMonitoring: true,
      description: |||
        This SLI monitors the status codes the runners are receiving from the GitLab.com API.

        An unusually high ratio of 4xx/5xx statuses indicates a potential problem.
      |||,
      significantLabels: ['endpoint'],

      monitoringThresholds+: {
        apdexScore: 0.90,
        errorRatio: 0.95,
      },

      requestRate: rateMetric(
        counter='gitlab_runner_api_request_statuses_total',
      ),

      errorRate: rateMetric(
        counter='gitlab_runner_api_request_statuses_total',
        selector={
          status: { oneOf: ['4..', '5..'], ne: '409' },
        },
      ),

      toolingLinks: [
        toolingLinks.kibana(title='CI Runners', index='runners', slowRequestSeconds=60),
      ],
    },

  },
  capacityPlanning+: {
    local dimensionedShards = $.shards,
    local ignoredShards = ['tamland'],
    saturation_dimensions: [
      { selector: selectors.serializeHash({ shard: shard }) }
      for shard in dimensionedShards
    ] + [
      {
        selector: selectors.serializeHash({ shard: { noneOf: dimensionedShards + ignoredShards } }),
        label: 'shard=rest-aggregated',
      },
    ],
    saturation_dimensions_keep_aggregate: false,
    components: [
      {
        name: 'node_schedstat_waiting',
        parameters: {
          ignore_outliers: [
            {
              start: '2023-07-01',
              end: '2023-09-10',
            },
          ],
        },
      },
      {
        name: 'disk_space',
        parameters: {
          ignore_outliers: [
            {
              start: '2023-11-01',
              end: '2023-12-15',
            },
          ],
        },
      },
    ],
  },
})
