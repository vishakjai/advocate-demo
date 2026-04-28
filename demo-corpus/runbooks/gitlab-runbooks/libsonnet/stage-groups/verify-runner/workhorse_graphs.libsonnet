local panel = import 'grafana/time-series/panel.libsonnet';

local longPollingRequestStateCounter =
  panel.timeSeries(
    'Workhorse long polling - request statuses',
    legendFormat='{{status}}',
    format='short',
    query=|||
      sum by (status) (
        increase(gitlab_workhorse_builds_register_handler_requests{environment=~"$environment",stage=~"$stage"}[$__rate_interval])
      )
    |||,
  );

local longPollingOpenRequests =
  panel.timeSeries(
    'Workhorse long polling - open requests',
    legendFormat='{{state}}',
    format='short',
    query=|||
      sum by (state) (
        gitlab_workhorse_builds_register_handler_open{environment=~"$environment",stage=~"$stage"}
      )
    |||,
  );

local queueingErrors =
  panel.timeSeries(
    'Workhorse queueing errors',
    legendFormat='{{type}}',
    format='ops',
    query=|||
      sum by (type) (
        increase(
          gitlab_workhorse_queueing_errors{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}[$__rate_interval]
        )
      )
    |||,
  );

local queueingHandledRequests =
  panel.multiTimeSeries(
    'Workhorse queueing - handled requests',
    queries=[
      {
        legendFormat: 'handled',
        query: |||
          sum(
            gitlab_workhorse_queueing_busy{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}
          )
        |||,
      },
      {
        legendFormat: 'limit',
        query: |||
          sum(
            gitlab_workhorse_queueing_limit{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}
          )
        |||,
      },
    ],
  );

local queueingQueuedRequests =
  panel.multiTimeSeries(
    'Workhorse queueing - queued requests',
    queries=[
      {
        legendFormat: 'queued',
        query: |||
          sum(
            gitlab_workhorse_queueing_waiting{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}
          )
        |||,
      },
      {
        legendFormat: 'limit',
        query: |||
          sum(
            gitlab_workhorse_queueing_queue_limit{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}
          )
        |||,
      },
    ],
  );

local queueingTime =
  local queueingTimeQuery(percentile) =
    {
      legendFormat: '%dth percentile' % percentile,
      query: |||
        histogram_quantile(
          0.%d,
          sum by (le) (
            rate(
              gitlab_workhorse_queueing_waiting_time_bucket{environment=~"$environment",stage=~"$stage",queue_name="ci_api_job_requests"}[$__rate_interval]
            )
          )
        )
      ||| % percentile,
    };
  panel.multiTimeSeries(
    'Workhorse queueing time',
    format='s',
    queries=[
      (
        queueingTimeQuery(percentile)
      )
      for percentile in [50, 90, 95, 99]
    ],
  );

{
  longPollingRequestStateCounter:: longPollingRequestStateCounter,
  longPollingOpenRequests:: longPollingOpenRequests,
  queueingErrors:: queueingErrors,
  queueingHandledRequests:: queueingHandledRequests,
  queueingQueuedRequests:: queueingQueuedRequests,
  queueingTime:: queueingTime,
}
