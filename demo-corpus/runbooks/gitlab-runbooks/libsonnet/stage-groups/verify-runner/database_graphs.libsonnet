local keyMetrics = import 'gitlab-dashboards/key_metrics.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local patroniCiService = (import 'servicemetrics/metrics-catalog.libsonnet').getService('patroni-ci');
local panels = import './panels.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local patroniOverview(startRow, rowHeight) =
  keyMetrics.headlineMetricsRow(
    patroniCiService.type,
    selectorHash={
      type: patroniCiService.type,
      tier: patroniCiService.tier,
      environment: '$environment',
      stage: '$stage',
    },
    showApdex=true,
    showErrorRatio=true,
    showOpsRate=true,
    showSaturationCell=true,
    showDashboardListPanel=false,
    compact=true,
    rowTitle=null,
    startRow=startRow,
    rowHeight=rowHeight,
  );

local totalDeadTuples =
  panel.timeSeries(
    'Total dead tuples',
    format='short',
    legendFormat='{{relname}}',
    query=|||
      max by(relname) (pg_stat_user_tables_n_dead_tup{environment=~"$environment",stage=~"$stage",datname="$db_database",relname=~"$db_top_dead_tup"})
    |||,
  );

local deadTuplesPercentage =
  panel.timeSeries(
    'Dead tuples percentage',
    format='percentunit',
    legendFormat='{{relname}}',
    query=|||
      max by(relname) (pg_stat_user_tables_n_dead_tup{environment=~"$environment",stage=~"$stage",datname="$db_database",relname=~"$db_top_dead_tup"})
      /
      (
        max by(relname) (pg_stat_user_tables_n_live_tup{environment=~"$environment",stage=~"$stage",datname="$db_database",relname=~"$db_top_dead_tup"})
        +
        max by(relname) (pg_stat_user_tables_n_dead_tup{environment=~"$environment",stage=~"$stage",datname="$db_database",relname=~"$db_top_dead_tup"})
      )
    |||,
  );

local slowQueries =
  panel.timeSeries(
    'Slow queries',
    format='opm',
    legendFormat='{{instance}}',
    query=|||
      rate(pg_slow_queries{environment=~"$environment",stage=~"$stage",fqdn=~"$db_instances"}[$__rate_interval]) * 60
    |||,
  );

local longRunningTransactionsCount =
  panel.timeSeries(
    'Long Running Transactions count',
    format='short',
    legendFormat='{{instance}}',
    query=|||
      pg_long_running_transactions_transactions{environment=~"$environment",stage=~"$stage",type="patroni-ci"}
    |||
  );

local longRunningTransactionMaxAge =
  panel.timeSeries(
    'Long Running Transactions max age',
    format='seconds',
    legendFormat='{{instance}}',
    query=|||
      pg_long_running_transactions_age_in_seconds{environment=~"$environment",stage=~"$stage",type="patroni-ci"}
    |||
  );

local bigQueryDuration(runner_type) = panels.heatmap(
  title='%s - duration of the builds queue retrieval SQL query' % runner_type,
  query=|||
    sum by (le) (
      increase(
        gitlab_ci_queue_retrieval_duration_seconds_bucket{
          environment=~"$environment",
          stage=~"$stage",
          runner_type=~"%(runner_type)s"
        }[$__rate_interval]
      )
    )
  ||| % {
    runner_type: runner_type,
  },
  description=|||
    The "big query SQL" is the SQL query GitLab uses to retrieve the jobs queue from the database. That query
    is used to add initial filtering and sorting of the queue. It's the core of jobs scheduling mechanism.

    With more and more of jobs in the ci_pending_builds table it's getting longer. At some level it may start
    affecting the whole system. The direct consequences will be seen as jobs queuing duration getting longer
    (which affects Runner's apdex) and general database slowness for the CI database.

    Therefore, observing the trend of our "big query SQL" duration is important.
  |||,
  color_mode='spectrum',
  color_colorScheme='Purples',
  legend_show=true,
  intervalFactor=1,
);

{
  patroniOverview:: patroniOverview,
  totalDeadTuples:: totalDeadTuples,
  deadTuplesPercentage:: deadTuplesPercentage,
  slowQueries:: slowQueries,
  longRunningTransactionsCount:: longRunningTransactionsCount,
  longRunningTransactionMaxAge:: longRunningTransactionMaxAge,
  bigQueryDuration:: bigQueryDuration,
}
