local panel = import 'grafana/time-series/panel.libsonnet';

local pipelineQueues =
  panel.timeSeries(
    'Sidekiq CI and Runner in flight jobs',
    description=|||
      This graph shows the rate of the Sidekiq jobs (related to CI/CD and Runner) that have been enqueued but not yet
      finished. A steep rise here means a backlog of jobs is being built and this means that Sidekiq is most probably
      having trouble keeping up.
    |||,
    legendFormat='{{worker}}',
    format='short',
    query=|||
      (
        sum by (worker) (
          ci_sidekiq_jobs_inflight:rate_5m{environment="$environment", stage="$stage"}
        )
      )
    |||,
  );

{
  pipelineQueues:: pipelineQueues,
}
