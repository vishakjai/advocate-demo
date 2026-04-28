local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local basic = import 'grafana/basic.libsonnet';
local dashboardHelpers = import 'stage-groups/verify-runner/dashboard_helpers.libsonnet';
local panels = import 'stage-groups/verify-runner//panels.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local filtering_query(metric) =
  'query_result(sum by(instance) (%(metric)s{environment=~"$environment", stage=~"$stage", shard=~"$shard"}) > 0)' % {
    metric: metric,
  };

local dmInstance = template.new(
  'dm_instance',
  '$PROMETHEUS_DS',
  query=filtering_query('gitlab_runner_autoscaling_actions_total'),
  regex='/.*instance="([^"]+)".*/',
  current=null,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
);

local autoscalerInstance = template.new(
  'autoscaler_instance',
  '$PROMETHEUS_DS',
  query=filtering_query('fleeting_taskscaler_scale_operations_total'),
  regex='/.*instance="([^"]+)".*/',
  current=null,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
);

local filters = [
  dmInstance,
  autoscalerInstance,
];

local jobsPoportion =
  basic.statPanel(
    title=null,
    panelTitle='Percent of Taskscaler/Fleeting powered jobs (compared to Docker Machine powered ones)',
    color='green',
    query=|||
      sum (
        gitlab_runner_jobs{environment=~"$environment", stage=~"$stage", instance=~"${autoscaler_instance:pipe}"}
      )
      /
      (
        sum(
          gitlab_runner_jobs{environment=~"$environment", stage=~"$stage", instance=~"${autoscaler_instance:pipe}"}
        )
        +
        sum(
          gitlab_runner_jobs{environment=~"$environment", stage=~"$stage", instance=~"${dm_instance:pipe}"}
        )
      )
    |||,
    unit='percentunit',
    decimals=2,
    colorMode='value',
    instant=true,
    interval='1d',
    intervalFactor=1,
    reducerFunction='last',
    justifyMode='center',
  );

local jobsRunning(partition, variable) =
  panel.timeSeries(
    title='Jobs running on runners (%s)' % partition,
    legendFormat='{{shard}}',
    format='short',
    fill=10,
    stack=true,
    linewidth=2,
    query=|||
      sum by(shard) (
        gitlab_runner_jobs{environment=~"$environment", stage=~"$stage", instance=~"${%(variable)s:pipe}"}
      )
    ||| % {
      variable: variable,
    },
  );

local jobsStarted(partition, variable) =
  panel.timeSeries(
    title='Jobs started on runners (%s)' % partition,
    legendFormat='{{shard}}',
    format='short',
    linewidth=2,
    fill=10,
    drawStyle='bars',
    stack=true,
    query=|||
      sum by(shard) (
        increase(
          gitlab_runner_jobs_total{environment=~"$environment", stage=~"$stage", instance=~"${%(variable)s:pipe}"}[$__rate_interval]
        )
      )
    ||| % {
      variable: variable,
    },
  );

local jobsFailed(partition, variable) =
  panel.timeSeries(
    title='Jobs failed on runners (%s)' % partition,
    legendFormat='{{shard}}',
    format='short',
    linewidth=2,
    fill=10,
    query=|||
      sum by(shard) (
        increase(
          gitlab_runner_failed_jobs_total{environment=~"$environment", stage=~"$stage", instance=~"${%(variable)s:pipe}"}[$__rate_interval]
        )
      )
    ||| % {
      variable: variable,
    },
  );

local queueDurationHistogram(partition, variable) =
  panels.heatmap(
    'Pending job queue duration (%s)' % partition,
    |||
      sum by (le) (
        increase(gitlab_runner_job_queue_duration_seconds_bucket{environment=~"$environment", stage=~"$stage", instance=~"${%(variable)s:pipe}"}[$__rate_interval])
      )
    ||| % {
      variable: variable,
    },
    color_mode='spectrum',
    color_colorScheme='Oranges',
    legend_show=true,
    intervalFactor=1,
  );

dashboardHelpers.dashboard(
  'Docker Machine to Autoscaler migration',
  time_from='now-12h/m',
)
.addTemplates(filters)
.addGrid(
  startRow=1000,
  rowHeight=2,
  panels=[
    jobsPoportion,
  ],
)
.addGrid(
  startRow=2000,
  rowHeight=8,
  panels=[
    jobsStarted('docker+machine', 'dm_instance'),
    jobsRunning('docker+machine', 'dm_instance'),
    jobsFailed('docker+machine', 'dm_instance'),
    queueDurationHistogram('docker+machine', 'dm_instance'),
  ],
)
.addGrid(
  startRow=3000,
  rowHeight=8,
  panels=[
    jobsStarted('docker-autoscaler', 'autoscaler_instance'),
    jobsRunning('docker-autoscaler', 'autoscaler_instance'),
    jobsFailed('docker-autoscaler', 'autoscaler_instance'),
    queueDurationHistogram('docker-autoscaler', 'autoscaler_instance'),
  ],
)
