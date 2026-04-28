local dashboardHelpers = import 'stage-groups/verify-runner/dashboard_helpers.libsonnet';
local jobInputsGraphs = import 'stage-groups/verify-runner/job_inputs_graphs.libsonnet';

dashboardHelpers.dashboard(
  'Job Inputs',
  time_from='now-12h/m',
)
.addGrid(
  startRow=1000,
  rowHeight=7,
  panels=[
    jobInputsGraphs.interpolationSuccessRate(),
    jobInputsGraphs.interpolationFailuresPieChart(),
  ],
)
.addGrid(
  startRow=2000,
  rowHeight=5,
  panels=[
    jobInputsGraphs.interpolationsCounter(),
  ],
)
.addGrid(
  startRow=3000,
  rowHeight=7,
  panels=[
    jobInputsGraphs.interpolationsRate(),
    jobInputsGraphs.interpolationFailuresRate(),
  ],
)
