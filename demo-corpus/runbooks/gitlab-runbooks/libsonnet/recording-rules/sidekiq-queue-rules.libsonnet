local alerts = import 'alerts/alerts.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local minimumOpRate = import 'slo-alerts/minimum-op-rate.libsonnet';
local serviceLevelAlerts = import 'slo-alerts/service-level-alerts.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';

/* TODO: having some sort of criticality label on sidekiq jobs would allow us to
   define different criticality labels for each worker. For now we need to use
   a fixed value, which also needs to be a lower-common-denominator */
local fixedApdexThreshold = 0.90;
local fixedErrorRateThreshold = 0.10;

local minimumSamplesForMonitoringApdex = 200; /* We don't really care if something runs only very infrequently, but is slow */

// NB: https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/1324 discusses increases the operation rate
// for some daily sidekiq jobs, to improve the sample rates.
local minimumSamplesForMonitoringErrors = 0.5; /* Low-frequency jobs may be doing very important things */

local sidekiqAlerts(registry, extraSelector) =
  [
    /**
       * Throttled queues don’t alert on queues SLOs.
       * This means that we will allow jobs to queue up for any amount of time without alerting.
       * One downside is that due to a misconfiguration, we may not be not listening to a throttled
       * queue.
       *
       * Since we don't have an SLO for this we can't use SLOs alert to tell us about this problem.
       * This alert is a safety mechanism. We don’t monitor queueing times, but if there were any
       * queuing jobs
       */
    {
      alert: 'sidekiq_throttled_jobs_enqueued_without_dequeuing',
      expr: |||
        (
          sum by (env, queue, feature_category, worker) (
            %(enqueueRate)s{%(selector)s}
          ) > 0
        )
        unless
        (
          sum by (env, queue, feature_category, worker) (
            %(executionRate)s{%(selector)s}
          ) > 0
        )
      ||| % {
        selector: selectors.serializeHash({ urgency: { eq: 'throttled' } } + extraSelector),
        enqueueRate: registry.recordingRuleNameFor('sidekiq_enqueued_jobs_total', '1h'),
        executionRate: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '1h'),
      },
      'for': '30m',
      labels: {
        type: 'sidekiq',  // Hardcoded because `gitlab_background_jobs:queue:ops:rate_1h` `type` label depends on the sidekiq client `type`
        tier: 'sv',  // Hardcoded because `gitlab_background_jobs:queue:ops:rate_1h` `type` label depends on the sidekiq client `type`
        stage: 'main',
        alert_type: 'cause',
        rules_domain: 'general',
        severity: 's4',
      },
      annotations: {
        title: 'Sidekiq jobs are being enqueued without being dequeued',
        description: |||
          The `{{ $labels.worker}}` worker in the {{ $labels.queue }} queue
          appears to have jobs being enqueued without those jobs being executed.

          This could be the result of a Sidekiq server configuration issue, where
          no Sidekiq servers are configured to dequeue the specific worker.
        |||,
        runbook: 'sidekiq/',
        grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
        grafana_variables: 'environment,stage,worker',
        grafana_min_zoom_hours: '6',
        promql_template_1: 'sidekiq_enqueued_jobs_total{environment="$environment", type="$type", stage="$stage", component="$component"}',
      },
    },
    {
      alert: 'SidekiqQueueNoLongerBeingProcessed',
      expr: |||
        (sum by(env, queue) (%(enqueueRate)s{%(selector)s})> 0.001)
        unless
        (sum by(env, queue) (%(executionRate)s{%(selector)s}) > 0)
      ||| % {
        selector: selectors.serializeHash(extraSelector),
        enqueueRate: registry.recordingRuleNameFor('sidekiq_enqueued_jobs_total', '6h'),
        executionRate: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '6h'),
      },
      'for': '20m',
      labels: {
        type: 'sidekiq',
        tier: 'sv',
        stage: 'main',
        alert_type: 'cause',
        rules_domain: 'general',
        severity: 's3',
      },
      annotations: {
        title: 'A Sidekiq queue is no longer being processed.',
        description: 'Sidekiq queue {{ $labels.queue }} in shard {{ $labels.shard }} is no longer being processed.',
        runbook: 'sidekiq/sidekiq-queue-not-being-processed/',
        grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
        grafana_panel_id: stableIds.hashStableId('request-rate'),
        grafana_variables: 'environment,stage,queue',
        grafana_min_zoom_hours: '6',
        promql_template_1: '%(executionRate6h)s{environment="$environment", queue="$queue"}' % {
          executionRate6h: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '6h'),
        },
      },
    },
    {
      alert: 'SidekiqWorkerNoLongerBeingProcessed',
      expr: |||
        (sum by(env, worker) (%(enqueueRate1h)s{%(selector)s})> 0.001)
        unless
        (sum by(env, worker) (%(executionRate1h)s{%(selector)s})  > 0)
      ||| % {
        selector: selectors.serializeHash(extraSelector),
        enqueueRate1h: registry.recordingRuleNameFor('sidekiq_enqueued_jobs_total', '1h'),
        executionRate1h: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '1h'),
      },
      'for': '20m',
      labels: {
        type: 'sidekiq',
        tier: 'sv',
        stage: 'main',
        alert_type: 'cause',
        rules_domain: 'general',
        severity: 's3',
      },
      annotations: {
        title: 'A Sidekiq worker is no longer being processed.',
        description: 'Sidekiq worker {{ $labels.worker }} in shard {{ $labels.shard }} is no longer being processed.',
        runbook: 'sidekiq/sidekiq-queue-not-being-processed/',
        grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
        grafana_panel_id: stableIds.hashStableId('request-rate'),
        grafana_variables: 'environment,stage,worker',
        grafana_min_zoom_hours: '6',
        promql_template_1: '%(executionRate6h)s{environment="$environment", worker="$worker"}' % {
          executionRate6h: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '6h'),
        },
      },
    },
    {
      alert: 'SidekiqJobsSkippedTooLong',
      expr: |||
        sum by (env, worker, action, reason)  (
          rate(
            sidekiq_jobs_skipped_total{%(selector)s}[1h]
            )
          )
          > 0
      ||| % {
        selector: selectors.serializeHash(extraSelector {
          reason: 'feature_flag',
        }),
      },
      'for': '3h',
      labels: {
        team: 'tenant_services',
        severity: 's4',
        alert_type: 'cause',
      },
      annotations: {
        title: 'Sidekiq jobs from `{{ $labels.worker }}` are intentionally being `{{ $labels.action }}` for too long',
        description: |||
          Sidekiq jobs from `{{ $labels.worker }}` are being `{{ $labels.action }}` indefinitely via feature flag `run_sidekiq_jobs_<worker_name>` or `drop_sidekiq_jobs_<worker_name>`. This feature flag might be used during an incident and forgotten
          to be removed.
          Ignore if this is still intentionally left.

          Run `/chatops gitlab run feature list --match run_sidekiq_jobs` and `/chatops gitlab run feature list --match drop_sidekiq_jobs` to list currently used feature flags.
        |||,
        grafana_dashboard_id: 'sidekiq-worker-detail',
        grafana_panel_id: stableIds.hashStableId('jobs-skipped'),
        grafana_min_zoom_hours: '6',
        grafana_variables: 'environment,worker',
      },
    },
    {
      alert: 'ScanDependenciesWorkerHighErrorRate',
      expr: |||
        sum by (env, worker) (
          application_sli_aggregation:sidekiq_execution:error:rate_5m{
            worker=~"Ai::RepositoryXray::ScanDependenciesWorker",
            %(selector)s
          }
        ) > 0.001
      ||| % {
        selector: selectors.serializeHash(extraSelector),
      },
      'for': '5m',
      labels: {
        severity: 's4',
        aggregation: 'sidekiq_execution',
        sli_type: 'error',
        alert_type: 'symptom',
        team: 'ai_coding',
      },
      annotations: {
        title: 'High error rate for `{{ $labels.worker }}`',
        description: |||
          Sidekiq jobs error rate from `{{ $labels.worker }}` has exceeded 0.1%. This may be caused by exceptions from unexpected data types or values in the job execution.
        |||,
        grafana_dashboard_id: 'sidekiq-worker-detail',
        grafana_min_zoom_hours: '6',
        grafana_variables: 'environment,worker',
      },
    },
    {
      alert: 'SidekiqJobsDeferredByDBHealthCheck',
      expr: |||
        sum by (env, worker, feature_category)  (
            rate(
                sidekiq_jobs_skipped_total{%(selectorNumerator)s}[1h]
            )
        )
        /
        sum by (env, worker, feature_category) (
            application_sli_aggregation:sidekiq_execution:ops:rate_1h{%(selectorDenominator)s}
        )
        > 0.1
      ||| % {
        selectorNumerator: selectors.serializeHash(extraSelector {
          action: 'deferred',
          reason: 'database_health_check',
        }),
        selectorDenominator: selectors.serializeHash(extraSelector),
      },
      'for': '2h',
      labels: {
        severity: 's4',
        alert_type: 'cause',
      },
      annotations: {
        title: 'Many Sidekiq jobs from `{{ $labels.worker }}` have been deferred by DB health check',
        description: |||
          {{ $value | humanizePercentage }} of Sidekiq jobs from `{{ $labels.worker }}` are being deferred via DB Health Check.

          Deferred jobs follow the same [indicators](https://docs.gitlab.com/ee/development/database/batched_background_migrations.html#throttling-batched-migrations) to throttle batched background migrations.

          When too many jobs are being deferred continuously, there could be a huge backlog of jobs impacting jobs from other worker classes.
        |||,
        grafana_dashboard_id: 'sidekiq-worker-detail',
        grafana_panel_id: stableIds.hashStableId('jobs-skipped'),
        grafana_min_zoom_hours: '6',
        grafana_variables: 'environment,worker',
      },
    },
    {
      alert: serviceLevelAlerts.nameSLOViolationAlert('sidekiq', 'WorkerExecution', 'ApdexSLOViolation'),
      expr: |||
        (
          (
            %(apdexSuccessRate1h)s{%(selector)s}
            /
            %(apdexTotalRate1h)s{%(selector)s}
          ) < %(apdexThreshold)s
          and
          (
            %(apdexSuccessRate5m)s{%(selector)s}
            /
            %(apdexTotalRate5m)s{%(selector)s}
          ) < %(apdexThreshold)s
        )
        and on (env, environment, tier, type, stage, shard, queue, feature_category, urgency, worker)
        (
          sum by (env, environment, tier, type, stage, shard, queue, feature_category, urgency, worker) (
            %(opsRate1h)s{%(selector)s}
          ) >= %(minimumOpRate)s
        )
      ||| % {
        apdexSuccessRate1h: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_apdex_success_total', '1h'),
        apdexTotalRate1h: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_apdex_total', '1h'),
        apdexSuccessRate5m: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_apdex_success_total', '5m'),
        apdexTotalRate5m: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_apdex_total', '5m'),
        opsRate1h: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '1h'),
        selector: selectors.serializeHash(extraSelector),
        minimumOpRate: minimumOpRate.calculateFromSamplesForDuration('1h', minimumSamplesForMonitoringApdex),
        apdexThreshold: fixedApdexThreshold,
      },
      'for': '1h',
      labels: {
        aggregation: 'sidekiq_execution',
        alert_class: 'slo_violation',
        alert_type: 'symptom',
        rules_domain: 'general',
        severity: 's4',
        sli_type: 'apdex',
        slo_alert: 'yes',
        window: '6h',
      },
      annotations: {
        title: 'The `{{ $labels.worker }}` Sidekiq worker, `{{ $labels.stage }}` stage, has an apdex violating SLO',
        description: |||
          The `{{ $labels.worker }}` worker is not meeting its apdex SLO.

          Currently the apdex value is {{ $value | humanizePercentage }}.
        |||,
        runbook: 'sidekiq/',
        grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
        grafana_panel_id: stableIds.hashStableId('execution-apdex'),
        grafana_variables: 'environment,stage,worker',
        grafana_min_zoom_hours: '6',
      },
    },
    {
      alert: serviceLevelAlerts.nameSLOViolationAlert('sidekiq', 'WorkerExecution', 'ErrorSLOViolation'),
      expr: |||
        (
          (
            %(errorRate1h)s{%(selector)s}
            /
            %(opsRate1h)s{%(selector)s}
          ) > %(errorThreshold)s
          and
          (
            %(errorRate5m)s{%(selector)s}
            /
            %(opsRate5m)s{%(selector)s}
          ) > %(errorThreshold)s
        )
        and on (env, environment, tier, type, stage, shard, queue, feature_category, urgency, worker)
        (
          sum by (env, environment, tier, type, stage, shard, queue, feature_category, urgency, worker) (
            %(opsRate1h)s{%(selector)s}
          ) >= %(minimumOpRate)s
        )
      ||| % {
        errorRate1h: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_error_total', '1h'),
        opsRate1h: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '1h'),
        errorRate5m: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_error_total', '5m'),
        opsRate5m: registry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '5m'),
        selector: selectors.serializeHash(extraSelector),
        minimumOpRate: minimumOpRate.calculateFromSamplesForDuration('1h', minimumSamplesForMonitoringErrors),
        errorThreshold: fixedErrorRateThreshold,
      },
      'for': '1h',
      labels: {
        aggregation: 'sidekiq_execution',
        alert_class: 'slo_violation',
        alert_type: 'symptom',
        rules_domain: 'general',
        severity: 's4',
        sli_type: 'error',
        slo_alert: 'yes',
        window: '6h',
      },
      annotations: {
        title: 'The `{{ $labels.worker }}` Sidekiq worker, `{{ $labels.stage }}` stage, has an error rate violating SLO',
        description: |||
          The `{{ $labels.worker }}` worker is not meeting its error-rate SLO.

          Currently the error-rate is {{ $value | humanizePercentage }}.
        |||,
        runbook: 'sidekiq/',
        grafana_dashboard_id: 'sidekiq-worker-detail/sidekiq-worker-detail',
        grafana_panel_id: stableIds.hashStableId('error-ratio'),
        grafana_variables: 'environment,stage,worker',
        grafana_min_zoom_hours: '6',
      },
    },
    {
      alert: 'SidekiqConcurrencyLimitQueueBacklogged',
      expr: |||
        max by (worker) (
          sidekiq_concurrency_limit_queue_jobs{%(selector)s}
        ) > 100000
      ||| % {
        selector: selectors.serializeHash(extraSelector),
      },
      local thresholdDuration = '1h',
      'for': thresholdDuration,
      labels: {
        alert_type: 'cause',
        severity: 's2',
        pager: 'pagerduty',
      },
      annotations: {
        title: 'The `{{ $labels.worker }}` Sidekiq worker has too many jobs being deferred by Concurrency Limit',
        description: |||
          The `{{ $labels.worker }}` worker has {{ $value }} jobs queued in the concurrency limit queue,
          exceeding the threshold for over %(thresholdDuration)s.

          IMPACT:
          • Memory saturation on Redis Cluster SharedState
          • Degraded `sidekiq_queueing` SLI apdex performance

          ROOT CAUSE:
          This typically indicates the worker's concurrency limit is too restrictive compared to the incoming job rate, or
          jobs are not processed fast enough due to other factors.

          RESOLUTION OPTIONS:
          1. If Redis Cluster SharedState's memory saturation and/or sidekiq queueing SLI is not impacted, ignore this alert.
          2. Enable the feature flag `disable_sidekiq_concurrency_limit_middleware_#{worker_name}` (example `disable_sidekiq_concurrency_limit_middleware_Security::SyncProjectPolicyWorker`)
             to disable concurrency limit middleware for this worker. This will stop incoming jobs to be deferred by concurrency limit middleware, allowing deferred jobs in
             concurrency limit queue to be cleared up.
          3. Increase the worker's concurrency limit
        ||| % {
          thresholdDuration: thresholdDuration,
        },
        runbook: 'sidekiq/sidekiq-concurrency-limit/',
        grafana_dashboard_id: 'sidekiq-concurrency/sidekiq-worker-concurrency-detail',
        grafana_panel_id: stableIds.hashStableId('queue-size'),
        grafana_variables: 'environment,worker',
        grafana_min_zoom_hours: '6',
      },
    },
    {
      alert: 'SidekiqWorkerThrottledByDBUsage',
      expr: |||
        sum by (worker, strategy) (
          sidekiq_throttling_events_total{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", strategy="HardThrottle"}
          -
          (
            sidekiq_throttling_events_total{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", strategy="HardThrottle"} offset 1m
            or
            sidekiq_throttling_events_total{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", strategy="HardThrottle"} * 0
          )
        ) > 0
      ||| % {
        selector: selectors.serializeHash(extraSelector),
      },
      local thresholdDuration = '5m',
      'for': thresholdDuration,
      labels: {
        alert_type: 'symptom',
        severity: 's3',
        team: 'tenant_services',
      },
      annotations: {
        title: 'The `{{ $labels.worker }}` Sidekiq worker has been throttled due to excessive DB usage',
        description: |||
          The `{{ $labels.worker }}` worker has been `HardThrottle`d for more than %(thresholdDuration)s
          due to these indicators: 1) exceeding DB duration usage and 2) predominantly holding too many DB connections.

          As a result, the worker's concurrency limit has been throttled/reduced significantly.

          Once the worker's DB usage has reduced to a normal level, the concurrency limit will be recovered gradually.
        ||| % {
          thresholdDuration: thresholdDuration,
        },
        runbook: 'sidekiq/sidekiq-concurrency-limit/',
        grafana_dashboard_id: 'sidekiq-concurrency/sidekiq-worker-concurrency-detail',
        grafana_panel_id: stableIds.hashStableId('throttling-events'),
        grafana_variables: 'environment,worker',
        grafana_min_zoom_hours: '6',
      },
    },
  ];

{
  sidekiqPerWorkerAlertRules(recordingRuleRegistry, extraSelector):
    alerts.processAlertRules(sidekiqAlerts(recordingRuleRegistry, extraSelector)),
}
