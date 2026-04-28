local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local template = grafana.template;

basic.dashboard(
  'Worker Concurrency Detail',
  tags=['type:sidekiq', 'detail'],
)
.addTemplate(templates.stage)
.addTemplate(template.new(
  'worker',
  '$PROMETHEUS_DS',
  'label_values(sidekiq_concurrency_limit_current_concurrent_jobs{environment="$environment", type="sidekiq"}, worker)',
  current='ProcessCommitWorker',
  refresh='load',
  sort=1,
  multi=true,
  includeAll=true,
  allValues='.*',
))
.addPanels(
  layout.rowGrid(
    'Concurrency limit queue',
    [
      panel.timeSeries(
        stableId='queue-size',
        title='Concurrency limit queue sizes',
        description='Number of jobs queued by the concurrency limit middleware',
        query=|||
          max by (worker) (
            max_over_time(
              sidekiq_concurrency_limit_queue_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"}[$__interval]
            )
          )
        |||,
        interval='1m',
        linewidth=1,

        legend_show=true,
      ),
      panel.timeSeries(
        title='Worker deferment rate',
        description='Rate of of jobs deferred by the concurrency limit middleware into the concurrency limit queue.',
        query=|||
          sum by (worker) (
            rate(
              sidekiq_concurrency_limit_deferred_jobs_total{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"}[$__interval]
            )
          )
        |||,
        interval='1m',
        linewidth=1,
        legend_show=true,
      ),
    ],
    startRow=100
  ) + layout.rowGrid(
    'Concurrency limit',
    [
      panel.timeSeries(
        title='Worker concurrency',
        description='Current number of concurrent running jobs.',
        query=|||
          max by (worker) (
            max_over_time(
              sidekiq_concurrency_limit_current_concurrent_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"}[$__interval]
            )
          )
        |||,
        interval='1m',
        linewidth=1,
        legend_show=true,
      ),
      panel.timeSeries(
        title='Max limit',
        description='Max number of concurrent running jobs.',
        query=|||
          max by (worker) (
            max_over_time(
              sidekiq_concurrency_limit_max_concurrent_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"}[$__interval]
            )
          )
        |||,
        interval='1m',
        linewidth=1,
        legend_show=true,
      ),
      panel.timeSeries(
        title='Current limit (subject to throttling)',
        description='Number of concurrent jobs currently allowed to run subject to throttling. Equal to `Max concurrency limit` under normal condition.',
        query=|||
          max by (worker) (
            max_over_time(
              sidekiq_concurrency_limit_current_limit{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"}[$__interval]
            )
          )
        |||,
        interval='1m',
        linewidth=1,
        legend_show=true,
      ),
      grafana.text.new(
        title='Details',
        mode='markdown',
        content=|||
          When `Worker concurrency` hits the limit, additional jobs are buffered in a separate Concurrency limit queue.

          All workers `Current limit` initially starts at `Max limit`. The `Current limit` is reduced (throttled) when the worker exceeds its database usage limits.

          Upon throttling, the current limit is gradually recovered towards its `Max limit`.
        |||
      ),
    ],
    startRow=200
  ) + layout.grid(
    [
      panel.timeSeries(
        stableId='throttling-events',
        title='Throttling Events',
        description='Shows whether a worker has been throttled',
        query=|||
          sum by (worker, strategy) (
            sidekiq_throttling_events_total{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"}
            -
            (
              sidekiq_throttling_events_total{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"} offset 1m
              or
              sidekiq_throttling_events_total{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"} * 0
            )
          )
        |||,
        interval='1m',
        linewidth=1,
        legend_show=true,
      ),
      grafana.text.new(
        title='Details',
        mode='markdown',
        content=|||
          A worker can be throttled based on 2 indicators, DB duration and the number of non-idle DB connections for jobs of a single worker class.
          Check [the runbooks doc](https://runbooks.gitlab.com/sidekiq/sidekiq-concurrency-limit/#database-usage-indicators) for more details.

          **DB duration usage (primary DBs only) Kibana links:**
            - [Main DB duration](https://log.gprd.gitlab.net/app/r/s/mvUdr)
            - [CI DB duration](https://log.gprd.gitlab.net/app/r/s/LcvLB)
            - [Sec DB duration](https://log.gprd.gitlab.net/app/r/s/bTMsh)

          **Number of non-idle DB connections dashboard links:**
            - [pgbouncer connection saturation](https://dashboards.gitlab.net/d/pgbouncer-main/pgbouncer3a-overview?orgId=1&from=now-6h%2Fm&to=now%2Fm&timezone=utc&var-PROMETHEUS_DS=mimir-gitlab-gprd&var-environment=gprd&viewPanel=panel-57)
            - [pgbouncer-ci connection saturation](https://dashboards.gitlab.net/d/pgbouncer-ci-main/pgbouncer-ci3a-overview?orgId=1&from=now-6h%2Fm&to=now%2Fm&timezone=utc&var-PROMETHEUS_DS=mimir-gitlab-gprd&var-environment=gprd&viewPanel=panel-57)
            - [pgbouncer-sec connection saturation](https://dashboards.gitlab.net/d/pgbouncer-sec-main/pgbouncer-sec3a-overview?orgId=1&from=now-6h%2Fm&to=now%2Fm&timezone=utc&var-PROMETHEUS_DS=mimir-gitlab-gprd&var-environment=gprd&viewPanel=panel-57)

          Definitions of `HardThrottle` and `SoftThrottle`
          can be found [here](https://runbooks.gitlab.com/sidekiq/sidekiq-concurrency-limit/#throttling-events).
        |||
      ),
    ],
    startRow=300
  )
)
.trailer()
+ {
  links+:
    platformLinks.triage +
    platformLinks.services +
    [
      platformLinks.dynamicLinks('Sidekiq Detail', 'type:sidekiq'),
    ],
}
