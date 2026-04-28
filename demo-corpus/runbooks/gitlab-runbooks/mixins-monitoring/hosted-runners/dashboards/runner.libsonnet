// runner.libsonnet
//
// Main hosted-runners Grafana dashboard.
//
// Terminology (Dedicated vs gitlab.com):
//   Shard ($shard) = gitlab.com Shard            — group of runner managers with same purpose/config
//   Fleeting       = gitlab.com Ephemeral VM      — short-lived VM created to execute a job
//
// Dashboard sections:
//   1.  Hosted Runner(s) Overview     — SLO headline metrics
//   2.  Deployment Details            — versions table, uptime table
//   3.  Runner Manager Overview       — status / job counter stat panels
//   4.  Jobs                          — running, started, failures, duration histogram
//   5.  Runner Saturation             — saturation time series & gauge
//   6.  Pending Jobs                  — queue histogram, pending builds, queuing exceeded/rate/duration
//   7.  Fleeting                      — full provisioner + taskscaler panels
//   8.  Workers                       — feed rate, slots, processing/health-check failures
//   9.  Request Concurrency           — limits, adaptive, in-flight, exceeded
//   10. API Requests                  — per-endpoint request rates
//   11. Polling                       — polling RPS / error

local grafana = import 'grafonnet/grafana.libsonnet';
local basic = import 'runbooks/libsonnet/grafana/basic.libsonnet';
local layout = import 'runbooks/libsonnet/grafana/layout.libsonnet';

local mappings = import '../lib/mappings.libsonnet';
local runnerPanels = import './panels/runner.libsonnet';
local vrp = import './panels/verify_runner_adapter.libsonnet';

local row = grafana.row;
local text = grafana.text;

// details(content) returns a full-width markdown text panel.
// Place it at the end of each section using an explicit gridPos.
local details(content) =
  text.new(
    title='',
    mode='markdown',
    content=content,
  );

{
  grafanaDashboards+:: {
    'hosted-runners.json':
      basic.dashboard(
        title='%s Overview' % $._config.dashboardName,
        tags=$._config.dashboardTags,
        editable=true,
        includeStandardEnvironmentAnnotations=false,
        includeEnvironmentTemplate=false,
        defaultDatasource=$._config.prometheusDatasource
      )
      .addTemplate($._config.templates.stackSelector)
      .addTemplate($._config.templates.shardSelector)

      // ── Section 1: Overview ────────────────────────────────────────────────
      .addPanels(
        runnerPanels.headlineMetricsRow(
          serviceType='hosted-runners',
          metricsCatalogServiceInfo=$._config.gitlabMetricsConfig.monitoredServices[0],
          selectorHash={ shard: [{ re: '.+-(${stack:pipe})' }, { re: '$shard' }] },
          showSaturationCell=false
        )
      )

      // ── Section 2: Deployment Details ─────────────────────────────────────
      .addPanels(layout.grid([
        runnerPanels.versionsTable('%s, %s' % [$._config.runnerJobSelector, $._config.runnerNameSelector]),
        runnerPanels.uptimeTable('%s, %s' % [$._config.runnerJobSelector, $._config.runnerNameSelector]),
      ], cols=2, rowHeight=6, startRow=0))

      // ── Section 3: Runner Manager Overview ────────────────────────────────
      .addPanel(
        row.new(title='Runner Manager Overview'),
        gridPos={ x: 0, y: 1000, w: 24, h: 1 }
      )
      // Runner Manager Status: full-width row, one tile per shard.
      // Query produces value 0 (Online) for shards with API activity, 1
      // (Offline) for shards present in version_info but with no API ops,
      // or 2 (Stale) for shards seen in the last 24h but no longer reporting.
      .addPanel(
        runnerPanels.statusPanel(
          title='Runner Manager Status',
          legendFormat='{{shard}}',
          query=|||
            (
              0 * (
                sum by(shard) (
                  gitlab_component_shard_ops:rate_5m{component="api_requests", %(runnerNameSelector)s}
                ) > 0
              )
            )
            or
            (
              0 * sum by(shard) (gitlab_runner_version_info{%(runnerNameSelector)s}) + 1
              unless on(shard) (
                sum by(shard) (
                  gitlab_component_shard_ops:rate_5m{component="api_requests", %(runnerNameSelector)s}
                ) > 0
              )
            )
            or
            (
              0 * sum by(shard) (last_over_time(gitlab_runner_version_info{%(runnerNameSelector)s}[24h])) + 2
              unless on(shard) (
                sum by(shard) (gitlab_runner_version_info{%(runnerNameSelector)s})
              )
            )
          ||| % $._config,
          valueMapping=mappings.onlineStatusMappings,
          allValues=true,
          textMode='value_and_name',
          description='Online: API requests in last 5 min. Offline: present in version_info but no API activity. Stale: seen within the last 24h but no longer reporting metrics.'
        ),
        gridPos={ x: 0, y: 1001, w: 24, h: 5 }
      )
      .addPanel(
        runnerPanels.statPanel(
          panelTitle='Total Jobs Executed',
          query=|||
            gitlab_runner_jobs_total{%(runnerNameSelector)s}
          ||| % $._config,
          color='blue',
          description='Number of jobs executed by this shard since it came up.'
        ),
        gridPos={ x: 0, y: 1002, w: 6, h: 5 }
      )
      .addPanel(
        runnerPanels.statPanel(
          panelTitle='Total Failed Jobs',
          query=|||
            sum by(shard) (
              gitlab_runner_failed_jobs_total{%(runnerNameSelector)s}
            )
          ||| % $._config,
          color='red',
          description='Number of jobs that have failed on this shard since it came up.'
        ),
        gridPos={ x: 6, y: 1002, w: 6, h: 5 }
      )
      .addPanel(
        runnerPanels.statPanel(
          panelTitle='Jobs Running',
          query=|||
            sum by(shard) (
              gitlab_runner_jobs{%(runnerNameSelector)s}
            )
          ||| % $._config,
          color='green',
          description='Number of jobs currently running on this shard.'
        ),
        gridPos={ x: 12, y: 1002, w: 6, h: 5 }
      )
      .addPanel(
        runnerPanels.statPanel(
          panelTitle='Concurrent Job Limit',
          query=|||
            gitlab_runner_concurrent{%(runnerNameSelector)s}
          ||| % $._config,
          color='yellow',
          description='Number of concurrent jobs this shard can handle.'
        ),
        gridPos={ x: 18, y: 1002, w: 6, h: 5 }
      )
      .addPanels(layout.grid([
        runnerPanels.runnerCaughtErrors($._config.runnerNameSelector),
        runnerPanels.totalApiRequests($._config.runnerNameSelector),
      ], cols=2, rowHeight=10, startRow=1003))

      // ── Section 4: Jobs ───────────────────────────────────────────────────
      .addPanel(
        row.new(title='Jobs'),
        gridPos={ x: 0, y: 2000, w: 24, h: 1 }
      )
      .addPanels(layout.grid([
        runnerPanels.runningJobs($._config.runnerNameSelector),
        runnerPanels.runningJobPhase($._config.runnerNameSelector),
        vrp.jobFailures(),
      ], cols=3, rowHeight=10, startRow=2001))
      .addPanel(
        vrp.finishedJobDurationsHistogram(),
        gridPos={ x: 0, y: 2002, w: 16, h: 10 }
      )
      .addPanel(
        vrp.finishedJobMinutesIncrease(),
        gridPos={ x: 16, y: 2002, w: 8, h: 10 }
      )

      // ── Section 5: Runner Saturation ──────────────────────────────────────
      .addPanel(
        row.new(title='Runner Saturation'),
        gridPos={ x: 0, y: 3000, w: 24, h: 1 }
      )
      .addPanels(layout.grid([
        runnerPanels.runnerSaturation(['shard'], 'concurrent', $._config.runnerNameSelector),
        runnerPanels.runnerSaturation(['shard'], 'limit', $._config.runnerNameSelector),
      ], cols=2, rowHeight=10, startRow=3001))

      // ── Section 6: Pending Jobs ───────────────────────────────────────────
      .addPanel(
        row.new(title='Pending Jobs'),
        gridPos={ x: 0, y: 4000, w: 24, h: 1 }
      )
      .addPanels(layout.grid([
        runnerPanels.ciPendingBuilds(),
        vrp.jobQueueSize(),
        vrp.pendingJobQueueDuration(),
        runnerPanels.averageDurationOfQueuing($._config.runnerNameSelector),
      ], cols=4, rowHeight=10, startRow=4002))
      .addPanels(layout.grid([
        vrp.jobQueuingExceeded(),
        vrp.jobsQueuingFailureRate(),
        runnerPanels.differentQueuingPhase(),
        vrp.jobQueueDepth(),
      ], cols=4, rowHeight=10, startRow=4002))

      // ── Section 7: Fleeting ───────────────────────────────────────────────
      .addPanel(
        row.new(title='Fleeting'),
        gridPos={ x: 0, y: 6000, w: 24, h: 1 }
      )
      .addPanels(layout.grid([
        vrp.provisionerInstancesSaturation(),
        vrp.provisionerInstancesStates(),
        vrp.taskscalerTasksSaturation(),
      ], cols=3, rowHeight=10, startRow=6001))
      .addPanels(layout.grid([
        vrp.taskscalerTasks(),
        vrp.taskscalerIdleRatio(),
        vrp.taskscalerDesiredInstances(),
      ], cols=3, rowHeight=10, startRow=6002))
      .addPanels(layout.grid([
        vrp.provisionerInstanceOperationsRate(),
        vrp.provisionerInternalOperationsRate(),
        vrp.provisionerMissedUpdates(),
      ], cols=3, rowHeight=10, startRow=6003))
      .addPanels(layout.grid([
        vrp.taskscalerOperationsRate(),
        vrp.taskscalerOperationsFailure(),
        vrp.taskscalerScaleOperationsRate(),
      ], cols=3, rowHeight=10, startRow=6004))
      .addPanels(layout.grid([
        vrp.provisionerCreationTiming(),
        vrp.provisionerIsRunningTiming(),
        vrp.provisionerDeletionTiming(),
      ], cols=3, rowHeight=10, startRow=6005))
      .addPanels(layout.grid([
        vrp.provisionerInstanceLifeDuration(),
        vrp.taskscalerMaxUseCountPerInstance(),
        vrp.taskscalerInstanceReadinessTiming(),
      ], cols=3, rowHeight=10, startRow=6006))

      // ── Section 8: Workers ────────────────────────────────────────────────
      .addPanel(
        row.new(title='Workers'),
        gridPos={ x: 0, y: 7000, w: 24, h: 1 }
      )
      .addPanels(layout.grid([
        vrp.workerFeedRate(),
        vrp.workerFeedFailuresRate(),
        vrp.workerSlots(),
      ], cols=3, rowHeight=10, startRow=7001))
      .addPanels(layout.grid([
        vrp.workerSlotOperationsRate(),
        vrp.workerProcessingFailuresRate(),
        vrp.workerHealthCheckFailuresRate(),
      ], cols=3, rowHeight=10, startRow=7002))

      // ── Section 9: Request Concurrency ───────────────────────────────────
      .addPanel(
        row.new(title='Request Concurrency'),
        gridPos={ x: 0, y: 8000, w: 24, h: 1 }
      )
      .addPanels(layout.grid([
        vrp.requestConcurrencyLimitsAndInFlight(),
        vrp.requestConcurrencyExceeded(),
      ], cols=2, rowHeight=10, startRow=8001))

      // ── Section 10: API Requests ──────────────────────────────────────────
      .addPanel(
        row.new(title='API Requests'),
        gridPos={ x: 0, y: 9000, w: 24, h: 1 }
      )
      .addPanels(layout.grid([
        vrp.runnerRequests('request_job'),
        vrp.runnerRequests('patch_trace'),
        vrp.runnerRequests('update_job'),
      ], cols=3, rowHeight=10, startRow=9001))

      // ── Section 11: Polling ───────────────────────────────────────────────
      .addPanel(
        row.new(title='Polling'),
        gridPos={ x: 0, y: 12000, w: 24, h: 1 }
      )
      .addPanels(layout.grid([
        runnerPanels.pollingRPS(),
        runnerPanels.pollingError(),
      ], cols=2, rowHeight=10, startRow=12001)),
  },
}
