local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local successCounterApdex = metricsCatalog.successCounterApdex;

metricsCatalog.serviceDefinition({
  type: 'ci-orchestration',
  tier: 'sv',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-ops', 'gitlab-pre'],
  serviceIsStageless: true,
  provisioning: {
    vms: false,
    kubernetes: false,
  },
  regional: false,
  serviceLevelIndicators: {
    pipelines_created: {
      userImpacting: true,
      featureCategory: 'continuous_integration',
      serviceAggregation: false,
      description: |||
        This monitors the creation rate of pipelines.

        It is emitted from Sidekiq by the `PipelineCreationMetricsWorker` used solely for metrics.
        This worker gets [emitted from the pipeline creation chain](https://gitlab.com/gitlab-org/gitlab/-/blob/ab35eba09564b33c41bac19eccac3635ee424574/lib/gitlab/ci/pipeline/chain/metrics.rb#L9)
        _after_ the pipeline has been created in Sidekiq, but before any jobs are available
        from being picked up by runners. It is only incremented for pipelines that
        were successfully created.
      |||,
      significantLabels: ['source'],

      requestRate: rateMetric(
        counter='pipelines_created_total',
      ),
      emittedBy: ['sidekiq'],
    },

    pipeline_creation_sidekiq_queue_duration: {
      userImpacting: true,
      serviceAggregation: false,
      featureCategory: 'continuous_integration',
      team: 'verify',
      severity: 's3',
      description: |||
        This SLI monitors the queue duration apdex for pipeline creation workers.

        It uses the Sidekiq queueing apdex SLI counters
        (`gitlab_sli_sidekiq_queueing_apdex_success_total` / `gitlab_sli_sidekiq_queueing_apdex_total`)
        filtered to pipeline creation workers (matching `.*CreatePipelineWorker.*`). The satisfied threshold is defined by the
        worker's urgency attribute in the application.
      |||,

      apdex: successCounterApdex(
        successRateMetric='gitlab_sli_sidekiq_queueing_apdex_success_total',
        operationRateMetric='gitlab_sli_sidekiq_queueing_apdex_total',
        selector={ worker: { re: '.*CreatePipelineWorker.*' } },
      ),

      requestRate: rateMetric(
        counter='gitlab_sli_sidekiq_queueing_apdex_total',
        selector={ worker: { re: '.*CreatePipelineWorker.*' } },
      ),

      emittedBy: ['sidekiq'],

      monitoringThresholds+: {
        apdexScore: 0.99,
      },

      significantLabels: ['worker'],
      toolingLinks: [],
    },

    pipeline_creation_sidekiq_execution: {
      userImpacting: true,
      serviceAggregation: false,
      featureCategory: 'continuous_integration',
      team: 'verify',
      severity: 's3',
      description: |||
        This SLI monitors the execution apdex and error rate for pipeline creation workers.

        It uses the Sidekiq execution SLI counters
        (`gitlab_sli_sidekiq_execution_apdex_success_total` / `gitlab_sli_sidekiq_execution_apdex_total`)
        filtered to pipeline creation workers (matching `.*CreatePipelineWorker.*`). The satisfied threshold is defined by the
        worker's urgency attribute in the application.
      |||,

      apdex: successCounterApdex(
        successRateMetric='gitlab_sli_sidekiq_execution_apdex_success_total',
        operationRateMetric='gitlab_sli_sidekiq_execution_apdex_total',
        selector={ worker: { re: '.*CreatePipelineWorker.*' } },
      ),

      requestRate: rateMetric(
        counter='gitlab_sli_sidekiq_execution_total',
        selector={ worker: { re: '.*CreatePipelineWorker.*' } },
      ),

      errorRate: rateMetric(
        counter='gitlab_sli_sidekiq_execution_error_total',
        selector={ worker: { re: '.*CreatePipelineWorker.*' } },
      ),

      emittedBy: ['sidekiq'],

      monitoringThresholds+: {
        apdexScore: 0.99,
        errorRatio: 0.9995,
      },

      significantLabels: ['worker'],
      toolingLinks: [],
    },

    pipeline_processing_sidekiq_queueing: {
      userImpacting: true,
      serviceAggregation: false,
      featureCategory: 'continuous_integration',
      team: 'verify',
      severity: 's3',
      description: |||
        This SLI monitors the queue duration apdex for pipeline processing workers.

        It uses the Sidekiq queueing apdex SLI counters
        (`gitlab_sli_sidekiq_queueing_apdex_success_total` / `gitlab_sli_sidekiq_queueing_apdex_total`)
        filtered to pipeline processing workers (`Ci::InitialPipelineProcessWorker`,
        `PipelineProcessWorker`, `Ci::BuildFinishedWorker`, `BuildQueueWorker`). The satisfied threshold is defined by the
        worker's urgency attribute in the application.
      |||,

      apdex: successCounterApdex(
        successRateMetric='gitlab_sli_sidekiq_queueing_apdex_success_total',
        operationRateMetric='gitlab_sli_sidekiq_queueing_apdex_total',
        selector={ worker: { re: 'Ci::InitialPipelineProcessWorker|PipelineProcessWorker|Ci::BuildFinishedWorker|BuildQueueWorker' } },
      ),

      requestRate: rateMetric(
        counter='gitlab_sli_sidekiq_queueing_apdex_total',
        selector={ worker: { re: 'Ci::InitialPipelineProcessWorker|PipelineProcessWorker|Ci::BuildFinishedWorker|BuildQueueWorker' } },
      ),

      emittedBy: ['sidekiq'],

      monitoringThresholds+: {
        apdexScore: 0.99,
      },

      significantLabels: ['worker'],
      toolingLinks: [],
    },

    pipeline_processing_sidekiq_execution: {
      userImpacting: true,
      serviceAggregation: false,
      featureCategory: 'continuous_integration',
      team: 'verify',
      severity: 's3',
      description: |||
        This SLI monitors the execution apdex and error rate for pipeline processing workers.

        It uses the Sidekiq execution SLI counters
        (`gitlab_sli_sidekiq_execution_apdex_success_total` / `gitlab_sli_sidekiq_execution_apdex_total`)
        filtered to pipeline processing workers (`Ci::InitialPipelineProcessWorker`,
        `PipelineProcessWorker`, `Ci::BuildFinishedWorker`, `BuildQueueWorker`). The satisfied threshold is defined by the
        worker's urgency attribute in the application.
      |||,

      apdex: successCounterApdex(
        successRateMetric='gitlab_sli_sidekiq_execution_apdex_success_total',
        operationRateMetric='gitlab_sli_sidekiq_execution_apdex_total',
        selector={ worker: { re: 'Ci::InitialPipelineProcessWorker|PipelineProcessWorker|Ci::BuildFinishedWorker|BuildQueueWorker' } },
      ),

      requestRate: rateMetric(
        counter='gitlab_sli_sidekiq_execution_total',
        selector={ worker: { re: 'Ci::InitialPipelineProcessWorker|PipelineProcessWorker|Ci::BuildFinishedWorker|BuildQueueWorker' } },
      ),

      errorRate: rateMetric(
        counter='gitlab_sli_sidekiq_execution_error_total',
        selector={ worker: { re: 'Ci::InitialPipelineProcessWorker|PipelineProcessWorker|Ci::BuildFinishedWorker|BuildQueueWorker' } },
      ),

      emittedBy: ['sidekiq'],

      monitoringThresholds+: {
        apdexScore: 0.99,
        errorRatio: 0.9995,
      },

      significantLabels: ['worker'],
      toolingLinks: [],
    },

    job_infra_failure_ratio: {
      userImpacting: true,
      serviceAggregation: false,
      featureCategory: 'continuous_integration',
      team: 'verify',
      severity: 's3',
      description: |||
        This SLI tracks the infra-attributable share of all CI job failures.

        The `gitlab_ci_job_failure_reasons` counter is incremented when a CI job
        fails. User- and external-attributable reasons are excluded from the
        error count (e.g. `script_failure`, `ci_quota_exceeded`,
        `no_matching_runner`, etc.). The result is the infra-attributable share
        of all job failures (0–100%).
      |||,

      requestRate: rateMetric(
        counter='gitlab_ci_job_failure_reasons',
      ),

      errorRate: rateMetric(
        counter='gitlab_ci_job_failure_reasons',
        selector={ reason: { nre: 'script_failure|ci_quota_exceeded|builds_disabled|user_blocked|stale_schedule|forward_deployment_failure|failed_outdated_deployment_job|api_failure|downstream_pipeline_creation_failed|downstream_bridge_project_not_found|insufficient_bridge_permissions|protected_environment_failure|no_matching_runner|runner_unsupported|secrets_provider_not_found|ip_restriction_failure|deployment_rejected|duo_workflow_not_allowed|invalid_bridge_trigger|job_token_expired|pipeline_loop_detected|reached_max_descendant_pipelines_depth|trace_size_exceeded|unmet_prerequisites|upstream_bridge_project_not_found|job_execution_timeout|missing_dependency_failure' } },
      ),

      emittedBy: ['api', 'ci-jobs-api', 'sidekiq', 'web'],

      monitoringThresholds+: {
        errorRatio: 0.95,
      },

      significantLabels: ['reason'],
      toolingLinks: [],
    },

    shared_runner_job_queue_duration: {
      userImpacting: true,
      serviceAggregation: false,
      featureCategory: 'continuous_integration',
      team: 'verify',
      severity: 's3',
      description: |||
        This SLI monitors the job queue duration for shared runners.

        The `job_queue_duration_seconds` histogram is emitted by the Rails API
        when a runner picks up a job via `POST /api/v4/jobs/request`. It measures
        the time between job creation and runner assignment.

        It is used to generate pre-aggregated recording rules for
        efficient p50/p99 trend queries over long time ranges (1d/7d/30d).
      |||,

      apdex: histogramApdex(
        histogram='job_queue_duration_seconds_bucket',
        selector={ shared_runner: 'true' },
        satisfiedThreshold=1,
        metricsFormat='migrating',
      ),

      requestRate: rateMetric(
        counter='job_queue_duration_seconds_count',
        selector={ shared_runner: 'true' },
      ),

      emittedBy: ['api', 'ci-jobs-api'],

      monitoringThresholds+: {
        apdexScore: 0.90,
      },

      significantLabels: [],
      toolingLinks: [],
    },

    non_shared_runner_job_queue_duration: {
      userImpacting: true,
      serviceAggregation: false,
      featureCategory: 'continuous_integration',
      team: 'verify',
      severity: 's3',
      description: |||
        This SLI monitors the job queue duration for non-shared (project/group) runners.

        The `job_queue_duration_seconds` histogram is emitted by the Rails API
        when a runner picks up a job via `POST /api/v4/jobs/request`. It measures
        the time between job creation and runner assignment.

        It is used to generate pre-aggregated recording rules for
        efficient p50/p99 trend queries over long time ranges (1d/7d/30d).
      |||,

      apdex: histogramApdex(
        histogram='job_queue_duration_seconds_bucket',
        selector={ shared_runner: 'false' },
        satisfiedThreshold=30,
        metricsFormat='migrating',
      ),

      requestRate: rateMetric(
        counter='job_queue_duration_seconds_count',
        selector={ shared_runner: 'false' },
      ),

      emittedBy: ['api', 'ci-jobs-api'],

      monitoringThresholds+: {
        apdexScore: 0.95,
      },

      significantLabels: [],
      toolingLinks: [],
    },
  },
  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'ci-orchestration is a virtual service that monitors CI pipeline orchestration metrics emitted by Rails (Sidekiq workers and API endpoints). It has no dedicated infrastructure or logging of its own.',
    'Service exists in the dependency graph': 'ci-orchestration is a virtual service that monitors CI pipeline orchestration metrics emitted by Rails (Sidekiq workers and API endpoints). It does not have its own infrastructure.',
  },
})
