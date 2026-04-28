local panel = import 'grafana/time-series/panel.libsonnet';

local defaultSelector = 'environment=~"$environment", stage=~"$stage", shard=~"${shard:pipe}"';

local jobRequestsOnWorkhorse =
  panel.timeSeries(
    '`jobs/request` requests',
    description='Rate of /api/v4/jobs/request calls reaching Workhorse, across all runners in the environment.',
    format='ops',
    legendFormat='requests',
    query=|||
      sum(
        job:gitlab_workhorse_http_request_duration_seconds_count:rate1m{environment=~"$environment",stage=~"$stage",route=~".*/api/v4/jobs/request.*"}
      )
    |||,
  );

local runnerRequests(endpoint, statuses='.*', selector=defaultSelector) =
  panel.timeSeries(
    'Runner requests for %(endpoint)s [%(statuses)s]' % {
      endpoint: endpoint,
      statuses: statuses,
    },
    description='Rate of runner API calls to GitLab for the %s endpoint, broken down by HTTP status code.' % endpoint,
    format='ops',
    legendFormat='{{status}}',
    drawStyle='bars',
    query=|||
      sum by(status) (
        increase(
          gitlab_runner_api_request_statuses_total{%(selector)s, endpoint="%(endpoint)s", status=~"%(statuses)s"}[$__rate_interval]
        )
      )
    ||| % {
      selector: selector,
      endpoint: endpoint,
      statuses: statuses,
    },
  );

{
  defaultSelector:: defaultSelector,
  jobRequestsOnWorkhorse:: jobRequestsOnWorkhorse,
  runnerRequests:: runnerRequests,
}
