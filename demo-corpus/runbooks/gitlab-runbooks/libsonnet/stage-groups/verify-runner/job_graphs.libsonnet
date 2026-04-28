local helpers = import './helpers.libsonnet';
local panels = import './panels.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local defaultSelector = 'environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"';

local runningJobsGraph(aggregators=[], selector=defaultSelector) =
  helpers.aggregationTimeSeries(
    'Jobs running (by %s)',
    |||
      sum by(%%s) (
        gitlab_runner_jobs{%(selector)s}
      )
    ||| % { selector: selector },
    aggregators,
    description='Current number of jobs actively running on runner managers.',
  );

local runnerJobFailuresGraph(aggregators=[], selector=defaultSelector) =
  helpers.aggregationTimeSeries(
    'Failures on runners (by %s)',
    |||
      sum by (%%s)
      (
        increase(gitlab_runner_failed_jobs_total{%(selector)s}[$__rate_interval])
      )
    ||| % { selector: selector },
    aggregators,
    description='Rate of job failures by failure reason.',
  );

local startedJobsGraph(aggregators=[], stack=true, selector=defaultSelector) =
  helpers.aggregationTimeSeries(
    'Jobs started on runners (by %s)',
    |||
      sum by(%%s) (
        increase(gitlab_runner_jobs_total{%(selector)s}[$__rate_interval])
      )
    ||| % { selector: selector },
    aggregators,
    stack=stack,
    description='Rate of new jobs started on runner managers per rate interval.',
  );

local startedJobsQuery(interval='$__rate_interval', selector=defaultSelector) =
  |||
    sum by(shard) (
      increase(
        gitlab_runner_jobs_total{%(selector)s}[%(interval)s]
      )
    )
  ||| % { interval: interval, selector: selector };

local startedJobsPieChart() =
  panels.pieChart(
    'Started jobs',
    query=startedJobsQuery(interval='$__range'),
    legendFormat='{{shard}}',
    instant=true,
    description='Distribution of started jobs across shards over the dashboard time range.',
  );

local startedJobsCounter() =
  basic.statPanel(
    title=null,
    panelTitle='Started jobs',
    color='green',
    query=startedJobsQuery(),
    legendFormat='{{shard}}',
    unit='short',
    decimals=1,
    colorMode='value',
    instant=false,
    interval='1d',
    intervalFactor=1,
    reducerFunction='sum',
    justifyMode='center',
    description='Total number of jobs started across all runner managers over the dashboard time range.',
  );

local finishedJobsDurationHistogram(selector=defaultSelector) =
  panels.heatmap(
    'Finished job durations histogram',
    |||
      sum by (le) (
        rate(gitlab_runner_job_duration_seconds_bucket{%(selector)s}[$__rate_interval])
      )
    ||| % { selector: selector },
    color_mode='spectrum',
    color_colorScheme='Blues',
    legend_show=true,
    intervalFactor=1,
    description='Heatmap of job durations. A shift toward longer durations can indicate runner or infrastructure slowdowns.',
  );

local finishedJobsMinutesIncreaseGraph(selector=defaultSelector) =
  panel.timeSeries(
    title='Finished job minutes increase',
    description='Total job-minutes consumed per rate interval by shard. The red average line is sampled at a coarser interval to smooth out short-term fluctuations. Useful for tracking overall compute consumption trends.',
    legendFormat='{{shard}}',
    format='short',
    interval='',
    intervalFactor=5,
    drawStyle='bars',
    stack=true,
    query=|||
      sum by(shard) (
        increase(gitlab_runner_job_duration_seconds_sum{%(selector)s}[$__rate_interval])
      )/60
    ||| % { selector: selector },
  ).addTarget(
    target.prometheus(
      |||
        avg (
          increase(gitlab_runner_job_duration_seconds_sum{%(selector)s}[$__rate_interval])
        )/60
      ||| % { selector: selector },
      legendFormat='avg',
      intervalFactor=10,
    )
  ).addSeriesOverride({
    alias: 'avg',
    drawStyle: 'line',
    color: '#ff0000ff',
    linewidth: 2,
  });

local finishedJobsMinutesIncreaseQuery(interval='$__rate_interval', selector=defaultSelector) =
  |||
    sum by(shard) (
      increase(
        gitlab_runner_job_duration_seconds_sum{%(selector)s}[%(interval)s]
      )
    )/60
  ||| % { interval: interval, selector: selector };

local finishedJobsMinutesIncreasePieChart() =
  panels.pieChart(
    'Finished job minutes increase',
    query=finishedJobsMinutesIncreaseQuery(interval='$__range'),
    legendFormat='{{shard}}',
    instant=true,
    description='Distribution of job-minutes consumed across shards over the dashboard time range.',
  );

local finishedJobsMinutesIncreaseCounter() =
  basic.statPanel(
    title=null,
    panelTitle='Finished job minutes increase',
    color='green',
    query=finishedJobsMinutesIncreaseQuery(),
    legendFormat='{{shard}}',
    unit='short',
    decimals=1,
    colorMode='value',
    instant=false,
    interval='1d',
    intervalFactor=1,
    reducerFunction='sum',
    justifyMode='center',
    description='Total job-minutes consumed across all runner managers over the dashboard time range.',
  );

{
  defaultSelector:: defaultSelector,
  running:: runningJobsGraph,
  failures:: runnerJobFailuresGraph,
  started:: startedJobsGraph,
  finishedJobsMinutesIncrease:: finishedJobsMinutesIncreaseGraph,

  startedCounter:: startedJobsCounter,
  startedPieChart:: startedJobsPieChart,
  finishedJobsMinutesIncreaseCounter:: finishedJobsMinutesIncreaseCounter,
  finishedJobsMinutesIncreasePieChart:: finishedJobsMinutesIncreasePieChart,

  finishedJobsDurationHistogram:: finishedJobsDurationHistogram,
}
