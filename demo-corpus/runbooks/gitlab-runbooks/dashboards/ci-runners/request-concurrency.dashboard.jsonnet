local dashboardHelpers = import 'stage-groups/verify-runner/dashboard_helpers.libsonnet';
local jobGraphs = import 'stage-groups/verify-runner/job_graphs.libsonnet';
local jobQueueGraphs = import 'stage-groups/verify-runner/job_queue_graphs.libsonnet';
local requestConcurrency = import 'stage-groups/verify-runner/request_concurrency.libsonnet';

dashboardHelpers.dashboard(
  'Request concurrency',
  includeStandardEnvironmentAnnotations=false,
)
.addRowGrid(
  title='${shard}',
  startRow=100,
  repeat='shard',
  panels=[
    requestConcurrency.limitsAndInFlight(),
    requestConcurrency.exceeded(),
    jobQueueGraphs.pendingSize(),
    jobQueueGraphs.queueDepth(),
    jobGraphs.started(['shard'], stack=false),
  ]
)
