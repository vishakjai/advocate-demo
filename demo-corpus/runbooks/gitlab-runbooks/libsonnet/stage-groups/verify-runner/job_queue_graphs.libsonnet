local panels = import './panels.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local ts = g.panel.timeSeries;

local defaultSelector = 'environment=~"$environment", stage=~"$stage", shard=~"${shard:pipe}"';

local durationHistogram(selector=defaultSelector) = panels.heatmap(
  'Pending job queue duration histogram',
  |||
    sum by (le) (
      increase(gitlab_runner_job_queue_duration_seconds_bucket{%(selector)s}[$__rate_interval])
    )
  ||| % { selector: selector },
  color_mode='spectrum',
  color_colorScheme='Oranges',
  legend_show=true,
  intervalFactor=1,
  description='Distribution of time jobs spend in the queue before a runner accepts them. A widening or rising distribution indicates runners cannot keep up with the incoming job rate.',
);

local pendingSize(selector=defaultSelector) =
  panel.timeSeries(
    title='Pending jobs queue size',
    description='Number of jobs in the candidate list Rails returns to the runner on a request_job call, filtered to eligible jobs for this runner.',
    legendFormat='{{runner_type}}',
    format='short',
    linewidth=2,
    query=|||
      max by(shard) (
        gitlab_runner_job_queue_size{%(selector)s}
      )
    ||| % { selector: selector },
  );

local queueDepth(selector=defaultSelector) =
  panel.timeSeries(
    title='Pending jobs queue depth',
    legendFormat='{{shard}}',
    format='short',
    linewidth=2,
    description=|||
      The number of iterations Rails performs over the initial job list before finding
      a job that can be assigned to the requesting runner. A job may be skipped if it
      has unmet requirements or was already assigned to another runner.

      High depth relative to queue size means many jobs in the list are not eligible
      for the runner, which increases latency for job assignment.
    |||,
    query=|||
      max by(shard) (
        gitlab_runner_job_queue_depth{%(selector)s}
      )
    ||| % { selector: selector },
    min=1,
  );

local acceptableQueuingDurationExceeded(selector=defaultSelector) =
  panel.timeSeries(
    title='Acceptable job queuing duration exceeded',
    description='Count of jobs that waited longer than the acceptable queuing duration SLO threshold. Sustained non-zero values are worth investigating.',
    legendFormat='{{shard}}',
    format='short',
    linewidth=2,
    query=|||
      sum by (shard) (
        increase(
          gitlab_runner_acceptable_job_queuing_duration_exceeded_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local queuingFailureRate(selector=defaultSelector) =
  panel.timeSeries(
    title='Jobs queuing failure rate',
    description='Percentage of total jobs that exceeded the acceptable queuing duration SLO threshold.',
    legendFormat='{{shard}}',
    format='percentunit',
    linewidth=2,
    query=|||
      sum by (shard) (
        rate(
          gitlab_runner_acceptable_job_queuing_duration_exceeded_total{%(selector)s}[$__rate_interval]
        )
      )
      /
      sum by (shard) (
        rate(
          gitlab_runner_jobs_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local gitlabJobQueueOperation(operation) =
  panel.multiTimeSeries(
    title='GitLab Job Queue operation rate - %s' % operation,
    description='Server-side CI queue %s rate (current vs. 1 week ago). A falling pop rate relative to push rate means jobs are piling up faster than runners can consume them.' % operation,
    format='short',
    linewidth=1,
    queries=[
      {
        query: |||
          sum (
            increase(
              gitlab_ci_queue_operations_total{environment=~"$environment", operation="build_queue_%(operation)s"}[$__rate_interval]
            )
          )
        ||| % {
          operation: operation,
        },
        legendFormat: 'Operations rate',
      },
      {
        query: |||
          sum (
            increase(
              gitlab_ci_queue_operations_total{environment=~"$environment", operation="build_queue_%(operation)s"}[$__rate_interval] offset 1w
            )
          )
        ||| % {
          operation: operation,
        },
        legendFormat: 'Operations rate (-1 week)',
      },
    ]
  )
  + ts.standardOptions.withOverridesMixin({
    matcher: {
      id: 'byName',
      options: 'Operations rate',
    },
    properties: [
      {
        id: 'custom.lineWidth',
        value: 2,
      },
      {
        id: 'color',
        value: {
          mode: 'fixed',
          fixedColor: 'red',
        },
      },
    ],
  })
  + ts.standardOptions.withOverridesMixin({
    matcher: {
      id: 'byName',
      options: 'Operations rate (-1 week)',
    },
    properties: [
      {
        id: 'custom.lineWidth',
        value: 2,
      },
      {
        id: 'custom.lineStyle',
        value: {
          dash: [10, 5, 2, 5],
          fill: 'dash',
        },
      },
      {
        id: 'color',
        value: {
          mode: 'fixed',
          fixedColor: 'gray',
        },
      },
    ],
  });

{
  defaultSelector:: defaultSelector,
  durationHistogram:: durationHistogram,
  pendingSize:: pendingSize,
  queueDepth:: queueDepth,
  acceptableQueuingDurationExceeded:: acceptableQueuingDurationExceeded,
  queuingFailureRate:: queuingFailureRate,
  gitlabJobQueuePush:: gitlabJobQueueOperation('push'),
  gitlabJobQueuePop:: gitlabJobQueueOperation('pop'),
}
