local configHandlingGraphs = import 'stage-groups/verify-runner/config_handling_graphs.libsonnet';
local dashboardFilters = import 'stage-groups/verify-runner/dashboard_filters.libsonnet';
local dashboardIncident = import 'stage-groups/verify-runner/dashboard_incident.libsonnet';
local jobGraphs = import 'stage-groups/verify-runner/job_graphs.libsonnet';
local resourcesGraphs = import 'stage-groups/verify-runner/resources_graphs.libsonnet';
local saturationGraphs = import 'stage-groups/verify-runner/saturation_graphs.libsonnet';
local workerGraphs = import 'stage-groups/verify-runner/worker_graphs.libsonnet';

dashboardIncident.incidentDashboard(
  'runner-manager',
  'rm',
  description=|||
    Runner Manager is the central point of job execution. It's responsible for asking GitLab for
    new jobs, executing them with the configured executor, collecting and sending back the job log
    and finally detecting the result of the job and reporting it back as well.

    Runner Manager orchestrates job's execution **for the whole lifetime of the running job**. Therefore
    problems on the Runner Manager side (usually related to resources usage or errors in configuration)
    affects the whole GitLab CI/CD experience.

    Known problem indicators:
    - high usage of Runner Manager VM resources,
    - high saturation of jobs (approaching defined limits),
    - highly increased number of job failures (especially the `runner_system_failure` type),
    - highly reduced number of jobs that are started by the Runner Manager.

    Runner Manager problems are usually caused by two possible reasons:
    - Not enough jobs capacity or resources capacity to the load being handled. For that concider
      adjusting the concurrency settings or resizing the Runner Manager VM to a more powerful one.
    - Bugs in Runner Manager configuration. For that double check if there were any changes made
      in Runner Manager's `config.toml` file.
  |||,
)
.addTemplate(dashboardFilters.runnerJobFailureReason)
.addGrid(
  panels=[
    saturationGraphs.runnerSaturation(aggregators=['shard'], saturationType='concurrent'),
    saturationGraphs.runnerSaturation(aggregators=['instance'], saturationType='concurrent'),
    saturationGraphs.runnerSaturation(aggregators=['instance', 'runner'], saturationType='limit'),
  ],
  rowHeight=8,
  startRow=3000,
)
.addGrid(
  panels=[
    resourcesGraphs.cpuUsage(),
    resourcesGraphs.memoryUsage(),
    resourcesGraphs.fdsUsage(),
  ],
  rowHeight=8,
  startRow=4000,
)
.addGrid(
  panels=[
    resourcesGraphs.diskAvailable(),
    resourcesGraphs.iopsUtilization(),
    resourcesGraphs.networkUtilization(),
  ],
  rowHeight=8,
  startRow=5000,
)
.addGrid(
  panels=[
    jobGraphs.failures(['instance', 'failure_reason']),
    jobGraphs.started(['instance']),
  ],
  rowHeight=8,
  startRow=6000,
)
.addRowGrid(
  'Jobs distribution',
  panels=[
    jobGraphs.running(['instance']),
    jobGraphs.running(['runner']),
    jobGraphs.running(['state']),
    jobGraphs.running(['exported_stage']),
    jobGraphs.running(['executor_stage']),
  ],
  startRow=7000,
)
.addRowGrid(
  'Workers & Slots',
  panels=[
    workerGraphs.workerFeedRate(),
    workerGraphs.workerSlots(),
    workerGraphs.workerSlotOperationsRate(),
  ],
  startRow=8000,
)
.addRowGrid(
  'Workers & Slots failures',
  panels=[
    workerGraphs.workerFeedFailuresRate(),
    workerGraphs.workerProcessingFailuresRate(),
    workerGraphs.workerHealthCheckFailuresRate(),
  ],
  startRow=9000,
)
.addRowGrid(
  'Config operations',
  panels=[
    configHandlingGraphs.successfulReloads(['instance']),
    configHandlingGraphs.reloadFailures(['instance']),
    configHandlingGraphs.successfulSaves(['instance']),
    configHandlingGraphs.saveFailures(['instance']),
  ],
  startRow=10000,
)
