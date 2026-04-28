// verify_runner_adapter.libsonnet
//
// Adapts panels from libsonnet/stage-groups/verify-runner/ for use in the
// hosted-runners dashboard by importing them directly and passing the
// hosted-runners selector.  Changes to the verify-runner panel definitions
// are automatically reflected here.
//
// The verify-runner panels use `environment=~"$environment"`, `stage=~"$stage"`
// and `shard=~"${shard:pipe}"` selectors that are not applicable to hosted
// runners.  This adapter re-exports those panels with:
//   - environment/stage labels removed (hosted runners don't filter by these)
//   - shard selector replaced with the hosted-runners stack+shard variables
//
// Panels excluded (gitlab.com infrastructure specific):
//   - autoscaling_graphs  : docker+machine executor, not used in hosted runners
//   - database_graphs     : patroni-ci specific, uses db_* template vars
//   - sidekiq_graphs      : CI sidekiq recording rules, environment/stage specific
//   - workhorse_graphs    : workhorse-side metrics, environment/stage specific
//   - api_graphs.jobRequestsOnWorkhorse : workhorse-side metric

local apiGraphs = import '../../../../libsonnet/stage-groups/verify-runner/api_graphs.libsonnet';
local fleetingGraphs = import '../../../../libsonnet/stage-groups/verify-runner/fleeting_graphs.libsonnet';
local jobGraphs = import '../../../../libsonnet/stage-groups/verify-runner/job_graphs.libsonnet';
local jobInputsGraphs = import '../../../../libsonnet/stage-groups/verify-runner/job_inputs_graphs.libsonnet';
local jobQueueGraphs = import '../../../../libsonnet/stage-groups/verify-runner/job_queue_graphs.libsonnet';
local requestConcurrency = import '../../../../libsonnet/stage-groups/verify-runner/request_concurrency.libsonnet';
local workerGraphs = import '../../../../libsonnet/stage-groups/verify-runner/worker_graphs.libsonnet';

// ---------------------------------------------------------------------------
// Selector helpers
// ---------------------------------------------------------------------------

// Primary selector: matches all shards belonging to the selected Stack(s),
// then optionally narrows to a specific deployment color via $shard.
local shard = 'shard=~".+-(${stack:pipe})", shard=~"$shard"';

// ---------------------------------------------------------------------------
// Exports
// ---------------------------------------------------------------------------

{
  // Fleeting provisioner panels
  provisionerInstancesSaturation:: function() fleetingGraphs.provisionerInstancesSaturation(shard),
  provisionerInstancesStates:: function() fleetingGraphs.provisionerInstancesStates(shard),
  provisionerMissedUpdates:: function() fleetingGraphs.provisionerMissedUpdates(shard),
  provisionerInstanceOperationsRate:: function() fleetingGraphs.provisionerInstanceOperationsRate(shard),
  provisionerInternalOperationsRate:: function() fleetingGraphs.provisionerInternalOperationsRate(shard),
  provisionerCreationTiming:: function() fleetingGraphs.provisionerCreationTiming(shard),
  provisionerIsRunningTiming:: function() fleetingGraphs.provisionerIsRunningTiming(shard),
  provisionerDeletionTiming:: function() fleetingGraphs.provisionerDeletionTiming(shard),
  provisionerInstanceLifeDuration:: function() fleetingGraphs.provisionerInstanceLifeDuration(shard),

  // Taskscaler panels
  taskscalerTasksSaturation:: function() fleetingGraphs.taskscalerTasksSaturation(shard),
  taskscalerMaxUseCountPerInstance:: function() fleetingGraphs.taskscalerMaxUseCountPerInstance(shard),
  taskscalerOperationsRate:: function() fleetingGraphs.taskscalerOperationsRate(shard),
  taskscalerOperationsFailure:: function() fleetingGraphs.taskscalerOperationsFailure(shard),
  taskscalerIdleRatio:: function() fleetingGraphs.taskscalerIdleRatio(shard),
  taskscalerTasks:: function() fleetingGraphs.taskscalerTasks(shard),
  taskscalerInstanceReadinessTiming:: function() fleetingGraphs.taskscalerInstanceReadinessTiming(shard),
  taskscalerScaleOperationsRate:: function() fleetingGraphs.taskscalerScaleOperationsRate(shard),
  taskscalerDesiredInstances:: function() fleetingGraphs.taskscalerDesiredInstances(shard),

  // Worker panels
  workerFeedRate:: function() workerGraphs.workerFeedRate(shard),
  workerFeedFailuresRate:: function() workerGraphs.workerFeedFailuresRate(shard),
  workerSlots:: function() workerGraphs.workerSlots(shard),
  workerSlotOperationsRate:: function() workerGraphs.workerSlotOperationsRate(shard),
  workerProcessingFailuresRate:: function() workerGraphs.workerProcessingFailuresRate(shard),
  workerHealthCheckFailuresRate:: function() workerGraphs.workerHealthCheckFailuresRate(shard),

  // Job panels (from job_graphs)
  jobFailures:: function(aggregators=['shard', 'failure_reason']) jobGraphs.failures(aggregators, selector=shard),
  finishedJobDurationsHistogram:: function() jobGraphs.finishedJobsDurationHistogram(selector=shard),
  finishedJobMinutesIncrease:: function() jobGraphs.finishedJobsMinutesIncrease(selector=shard),

  // Job queue panels
  jobQueueSize:: function() jobQueueGraphs.pendingSize(shard),
  jobQueueDepth:: function() jobQueueGraphs.queueDepth(shard),
  pendingJobQueueDuration:: function() jobQueueGraphs.durationHistogram(selector=shard),
  jobQueuingExceeded:: function() jobQueueGraphs.acceptableQueuingDurationExceeded(selector=shard),
  jobsQueuingFailureRate:: function() jobQueueGraphs.queuingFailureRate(selector=shard),

  // API panels
  runnerRequests:: function(endpoint, statuses='.*') apiGraphs.runnerRequests(endpoint, statuses, shard),

  // Request concurrency panels
  requestConcurrencyLimitsAndInFlight:: function() requestConcurrency.limitsAndInFlight(shard),
  requestConcurrencyExceeded:: function() requestConcurrency.exceeded(shard),

  // Job inputs panels
  jobInputsInterpolationsRate:: function() jobInputsGraphs.interpolationsRate(shard),
  jobInputsInterpolationFailuresRate:: function() jobInputsGraphs.interpolationFailuresRate(shard),
  jobInputsInterpolationSuccessRate:: function() jobInputsGraphs.interpolationSuccessRate(shard),
  jobInputsInterpolationFailuresPieChart:: function() jobInputsGraphs.interpolationFailuresPieChart(shard),
  jobInputsInterpolationsCounter:: function() jobInputsGraphs.interpolationsCounter(shard),
}
