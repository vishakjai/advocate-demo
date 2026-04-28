local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local statPanel = grafana.statPanel;
local colorScheme = import 'grafana/color_scheme.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

basic.dashboard(
  'Redis Detail',
  tags=['container registry', 'docker', 'registry', 'redis', 'cache'],
)
.addTemplate(templates.gkeCluster)
.addTemplate(templates.stage)
.addTemplate(templates.namespaceGitlab)
.addTemplate(
  template.custom(
    'Deployment',
    'gitlab-registry,',
    'gitlab-registry',
    hide='variable',
  )
)
.addTemplate(
  template.new(
    'cluster',
    '$PROMETHEUS_DS',
    'label_values(registry_redis_pool_stats_total_conns{environment="$environment"}, cluster)',
    current=null,
    refresh='load',
    sort=true,
    multi=true,
    includeAll=true,
    allValues='.*',
  )
)
.addTemplate(
  template.new(
    'instance',
    '$PROMETHEUS_DS',
    'label_values(registry_redis_pool_stats_total_conns{environment="$environment"}, instance)',
    current='cache',
    refresh='load',
    sort=true,
    multi=true,
    includeAll=true,
    allValues='.*',
  )
)
.addPanel(
  row.new(title='Overview'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    statPanel.new(
      title='RPS',
      description='The per-second rate of all Redis operations performed on the application side.',
      reducerFunction='last',
      decimals=0,
    )
    .addTarget(
      promQuery.target(
        |||
          sum (
            rate(registry_redis_single_commands_count{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval])
          )
        |||
      )
    ),
    statPanel.new(
      title='Key Count',
      description='The number of Redis keys.',
      unit='short',
    )
    .addTarget(
      promQuery.target(
        |||
          avg(
            max_over_time(
              redis_db_keys{deployment="redis-registry-cache", db="db0", env="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]
            )
          )
        |||
      )
    ),
    statPanel.new(
      title='Latency',
      description='The p90 latency of all Redis operations performed on the application side.',
      decimals=2,
      unit='s',
    )
    .addTarget(
      promQuery.target(
        |||
          histogram_quantile(
            0.900000,
            sum by (le) (
              rate(registry_redis_single_commands_bucket{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval])
            )
          )
        |||
      )
    ),
    statPanel.new(
      title='Open Connections',
      description='The total number of established connections both in use and idle.',
      reducerFunction='last',
      decimals=0,
    )
    .addTarget(
      promQuery.target(
        |||
          sum(
            max_over_time(
              registry_redis_pool_stats_total_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]
            )
          )
        |||
      )
    ),
    statPanel.new(
      title='Connection Pool Saturation',
      reducerFunction='last',
      decimals=0,
      unit='percentunit',
    )
    .addTarget(
      promQuery.target(
        |||
          (
            sum (registry_redis_pool_stats_total_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
            -
            sum (registry_redis_pool_stats_idle_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
          )
          /
          sum (registry_redis_pool_stats_max_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
        |||
      )
    )
    .addThresholds(
      [
        { color: colorScheme.normalRangeColor, value: 0.30 },
        { color: colorScheme.warningColor, value: 0.50 },
        { color: colorScheme.errorColor, value: 0.80 },
      ]
    ),
    statPanel.new(
      title='Connection Pool Hit Ratio',
      description='The percentage of time a free connection was found in the pool.',
      reducerFunction='last',
      decimals=0,
      unit='percentunit'
    )
    .addTarget(
      promQuery.target(
        |||
          sum (registry_redis_pool_stats_hits{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
          /
          (
            sum (registry_redis_pool_stats_hits{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
            +
            sum (registry_redis_pool_stats_misses{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
          )
        |||
      )
    ),
  ], cols=6, rowHeight=4, startRow=1)
)


.addPanel(
  row.new(title='Single Commands'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='RPS (Aggregate)',
        description='The per-second rate of all single command operations performed on the application side.',
        query=|||
          sum (
            rate(registry_redis_single_commands_count{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval])
          )
        |||,
        legend_show=false,
        format='ops'
      ),
      panel.basic(
        'RPS (Per Command)',
        description='The per-second rate of each single command operation performed on the application side.',
        unit='ops',
        linewidth=1,
        legend_show=false,
      )
      .addTarget(
        target.prometheus(
          |||
            sum by (command) (
              rate(registry_redis_single_commands_count{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval])
            )
          |||,
          legendFormat='{{ command }}',
        )
      ),
      panel.timeSeries(
        title='Latency (Aggregate)',
        description='The p90 latency of all single command operations performed on the application side.',
        query=|||
          histogram_quantile(
            0.900000,
            sum by (le) (
              rate(registry_redis_single_commands_bucket{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval])
            )
          )
        |||,
        legend_show=false,
        format='short'
      ),
      panel.basic(
        'Latency (Per Query)',
        description='The p90 latency of each single command operation performed on the application side.',
        unit='short',
        linewidth=1,
      )
      .addTarget(
        target.prometheus(
          |||
            histogram_quantile(
              0.900000,
              sum by (le, command) (
                rate(registry_redis_single_commands_bucket{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval])
              )
            )
          |||,
          legendFormat='{{ command }}',
        )
      ),
    ],
    cols=4,
    rowHeight=13,
    startRow=1001,
  ),
)
.addPanel(
  row.new(title='Connection Pool'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Hits',
        description='The number of times a free connection was found in the pool.',
        yAxisLabel='Count',
        query='sum(rate(registry_redis_pool_stats_hits{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]))',
        intervalFactor=5,
        legend_show=false
      ),
      panel.timeSeries(
        title='Misses',
        description='The number of times a free connection was not found in the pool.',
        yAxisLabel='Count',
        query='sum(rate(registry_redis_pool_stats_misses{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]))',
        intervalFactor=5,
        legend_show=false
      ),
      panel.timeSeries(
        title='Open',
        description='The total number of established connections both in use and idle.',
        yAxisLabel='Connections',
        query='sum(rate(registry_redis_pool_stats_total_conns{app="registry", environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))',
        intervalFactor=5,
        legend_show=false
      ),
      panel.timeSeries(
        title='In Use',
        description='The total number of connections currently in use.',
        yAxisLabel='Connections',
        query=|||
          sum(rate(registry_redis_pool_stats_total_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]))
          -
          sum(rate(registry_redis_pool_stats_idle_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]))
        |||,
        intervalFactor=5,
        legend_show=false
      ),
      panel.timeSeries(
        title='Idle',
        description='The number of idle connections in the pool.',
        yAxisLabel='Connections',
        query='sum(rate(registry_redis_pool_stats_idle_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]))',
        intervalFactor=5,
        legend_show=false
      ),
      panel.timeSeries(
        title='Stale',
        description='The number of stale connections removed from the pool.',
        yAxisLabel='Connections',
        query='sum(rate(registry_redis_pool_stats_stale_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]))',
        intervalFactor=5,
        legend_show=false
      ),
      panel.timeSeries(
        title='Timeouts',
        description='The number of times a wait timeout occurred.',
        yAxisLabel='Count',
        query='sum(rate(registry_redis_pool_stats_timeouts{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"}[$__interval]))',
        intervalFactor=5,
        legend_show=false
      ),
      panel.saturationTimeSeries(
        title='Saturation',
        description='Saturation. Lower is better.',
        yAxisLabel='Utilization',
        query=|||
          (
            sum (registry_redis_pool_stats_total_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
            -
            sum (registry_redis_pool_stats_idle_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
          )
          /
          sum (registry_redis_pool_stats_max_conns{environment="$environment", cluster=~"$cluster", stage="$stage", exported_instance=~"$instance"})
        |||,
        interval='30s',
        intervalFactor=3,
        legend_show=false
      ),
    ],
    cols=4,
    rowHeight=10,
    startRow=2001,
  ),
)
