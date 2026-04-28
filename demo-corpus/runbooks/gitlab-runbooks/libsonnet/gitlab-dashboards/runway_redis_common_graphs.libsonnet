local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local row = grafana.row;
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local override = import 'grafana/time-series/override.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

{
  clientPanels(serviceType, startRow)::
    local formatConfig = {
      selector: selectors.serializeHash({
        environment: '$environment',
        type: serviceType,
        shard: { re: '$shard' },
      }),
    };

    local panels = layout.grid(
      [
        panel.timeSeries(
          title='Connected Clients',
          yAxisLabel='Clients',
          query=|||
            max by (shard) (stackdriver_redis_instance_redis_googleapis_com_clients_connected{%(selector)s})
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Blocked Clients',
          description='Blocked clients are waiting for a state change event using commands such as BLPOP. Blocked clients are not a sign of an issue on their own.',
          yAxisLabel='Blocked Clients',
          query=|||
            max by (shard) (stackdriver_redis_instance_redis_googleapis_com_clients_blocked{%(selector)s})
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Connections Received',
          yAxisLabel='Connections',
          query=|||
            max by (shard) (stackdriver_redis_instance_redis_googleapis_com_stats_connections_total{%(selector)s})
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=2,
        ),
      ],
      cols=2,
      rowHeight=10,
      startRow=startRow + 1,
    );

    layout.titleRowWithPanels(
      title='Clients',
      collapse=false,
      startRow=startRow,
      panels=panels,
    ),


  workload(serviceType, startRow)::
    local formatConfig = {
      serviceType: serviceType,
      primarySelectorSnippet: 'and on (pod, fqdn) redis_instance_info{role="master", environment="$environment"}',
      replicaSelectorSnippet: 'and on (pod, fqdn) redis_instance_info{role="slave", environment="$environment"}',
      selector: selectors.serializeHash({
        environment: '$environment',
        type: serviceType,
        shard: { re: '$shard' },
      }),
    };
    local panels = layout.grid(
      [
        panel.timeSeries(
          title='Operation Rate - Primary',
          yAxisLabel='Operations/sec',
          query=|||
            sum by (shard) (
              stackdriver_redis_instance_redis_googleapis_com_commands_calls{%(selector)s, role = "primary"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Operation Rate - Replicas',
          yAxisLabel='Operations/sec',
          query=|||
            sum by (shard) (
              stackdriver_redis_instance_redis_googleapis_com_commands_calls{%(selector)s, role = "replica"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=1,
        ),
        panel.saturationTimeSeries(
          title='Redis CPU per instance - Primary',
          description='redis is single-threaded. This graph shows maximum utilization across all cores on each host. Lower is better.',
          query=|||
            sum by (shard, space) (
              stackdriver_redis_instance_redis_googleapis_com_stats_cpu_utilization{%(selector)s, role = "primary"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ shard }} {{ space }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.saturationTimeSeries(
          title='Redis CPU per Node - Replicas',
          description='redis is single-threaded. This graph shows maximum utilization across all cores on each host. Lower is better.',
          query=|||
            sum by (shard, space) (
              stackdriver_redis_instance_redis_googleapis_com_stats_cpu_utilization{%(selector)s, role = "primary"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ shard }} {{ space }}',
          interval='30s',
          intervalFactor=1,
        ),
        panel.timeSeries(
          title='Redis Network Out',
          format='Bps',
          query=|||
            sum by (shard, role) (
              stackdriver_redis_instance_redis_googleapis_com_stats_network_traffic{%(selector)s, direction = "out"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ shard}} {{ role }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Redis Network In',
          format='Bps',
          query=|||
            sum by (shard, role) (
              stackdriver_redis_instance_redis_googleapis_com_stats_network_traffic{%(selector)s, direction = "in"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ shard}} {{ role }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Redis Network In - Replicas',
          format='Bps',
          query=|||
            sum(rate(redis_net_input_bytes_total{%(selector)s}[$__interval])
              %(replicaSelectorSnippet)s
            ) by (fqdn, pod)
          ||| % formatConfig,
          legendFormat='{{ pod }} {{ fqdn }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Operation Rate per Command - Primary',
          yAxisLabel='Operations/sec',
          legend_show=false,
          query=|||
            sum by (shard, cmd) (
              stackdriver_redis_instance_redis_googleapis_com_commands_calls{%(selector)s, role = "primary"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ cmd }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Operation Rate per Command - Replicas',
          yAxisLabel='Operations/sec',
          legend_show=false,
          query=|||
            sum by (shard, cmd) (
              stackdriver_redis_instance_redis_googleapis_com_commands_calls{%(selector)s, role = "replica"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ cmd }}',
          intervalFactor=2,
        ),
        panel.latencyTimeSeries(
          title='Average Operation Latency - Primary',
          legend_show=false,
          format='us',
          query=|||
            max by (shard, cmd) (
              stackdriver_redis_instance_redis_googleapis_com_commands_usec_per_call{%(selector)s, role = "primary"}
            )
          ||| % formatConfig,
          legendFormat='{{ cmd }}',
          intervalFactor=2,
        ),
        panel.latencyTimeSeries(
          title='Average Operation Latency - Replicas',
          legend_show=false,
          format='us',
          query=|||
            max by (shard, cmd) (
              stackdriver_redis_instance_redis_googleapis_com_commands_usec_per_call{%(selector)s, role = "replica"}
            )
          ||| % formatConfig,
          legendFormat='{{ cmd }}',
          intervalFactor=2,
        ),
        panel.latencyTimeSeries(
          title='Total Operation Latency - Primary',
          legend_show=false,
          format='us',
          query=|||
            sum by (shard, cmd) (
              stackdriver_redis_instance_redis_googleapis_com_commands_total_time{%(selector)s, role = "primary"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ cmd }}',
          intervalFactor=2,
        ),
        panel.latencyTimeSeries(
          title='Total Operation Latency - Replicas',
          legend_show=false,
          format='us',
          query=|||
            sum by (shard, cmd) (
              stackdriver_redis_instance_redis_googleapis_com_commands_total_time{%(selector)s, role = "replica"}
            ) / 60
          ||| % formatConfig,
          legendFormat='{{ cmd }}',
          intervalFactor=2,
        ),
      ],
      cols=2,
      rowHeight=10,
      startRow=startRow + 1,
    );

    layout.titleRowWithPanels(
      title='Workload',
      collapse=false,
      startRow=startRow,
      panels=panels,
    ),

  data(serviceType, startRow)::
    local formatConfig = {
      selector: selectors.serializeHash({
        environment: '$environment',
        type: serviceType,
        shard: { re: '$shard' },
      }),
    };
    local charts =
      [
        panel.saturationTimeSeries(
          title='Memory Saturation',
          description='Redis holds all data in memory. Avoid memory saturation in Redis at all cost ',
          query=|||
            max by (shard) (
              stackdriver_redis_instance_redis_googleapis_com_stats_memory_usage_ratio{%(selector)s, role = "primary"}
            )
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          interval='30s',
          intervalFactor=1,
        )
        .addSeriesOverride(override.degradationSlo)
        .addSeriesOverride(override.outageSlo)
        .addTarget(
          target.prometheus(
            |||
              max(slo:max:soft:gitlab_component_saturation:ratio{component="redis_memory", environment="$environment"})
            ||| % formatConfig,
            interval='5m',
            legendFormat='Degradation SLO',
          ),
        )
        .addTarget(
          target.prometheus(
            |||
              max(slo:max:hard:gitlab_component_saturation:ratio{component="redis_memory", environment="$environment"})
            ||| % formatConfig,
            interval='5m',
            legendFormat='Outage SLO',
          ),
        ),
        panel.timeSeries(
          title='Memory Used',
          format='bytes',
          query=|||
            max by (shard) (
              stackdriver_redis_instance_redis_googleapis_com_stats_memory_usage{%(selector)s, role = "primary"}
            )
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Redis RSS Usage',
          description='Depending on the memory allocator used, Redis may not return memory to the operating system at the same rate that applications release keys. RSS indicates the operating systems perspective of Redis memory usage. So, even if usage is low, if RSS is high, the OOM killer may terminate the Redis process',
          format='bytes',
          query=|||
            max by (shard) (
              stackdriver_redis_instance_redis_googleapis_com_stats_memory_system_memory_usage_ratio{%(selector)s, role = "primary"}
            )
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Expired Keys',
          yAxisLabel='Keys',
          query=|||
            max by (shard) (
              stackdriver_redis_instance_redis_googleapis_com_stats_expired_keys{%(selector)s, role = "primary"}
            )
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=2,
        ),
        panel.timeSeries(
          title='Hit Ratio',
          yAxisLabel='Hits',
          format='percentunit',
          query=|||
            max by (shard) (
              stackdriver_redis_instance_redis_googleapis_com_stats_keyspace_hits{%(selector)s, role = "primary"}
            )
            /
            (
              max by (shard) (
                stackdriver_redis_instance_redis_googleapis_com_stats_keyspace_hits{%(selector)s, role = "primary"}
              )
              +
              max by (shard) (
                stackdriver_redis_instance_redis_googleapis_com_stats_keyspace_misses{%(selector)s, role = "primary"}
              )
            )
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=2,
        ),
      ];

    layout.titleRowWithPanels(
      title='Redis Data',
      collapse=false,
      startRow=startRow,
      panels=layout.grid(charts, cols=2, rowHeight=10, startRow=startRow + 1),
    ),

  runwayRedisDashboard(service)::
    serviceDashboard.overview(
      service,
      includeStandardEnvironmentAnnotations=false
    )
    .addTemplate(templates.runwayManagedRedisShard)
    .addPanels(self.clientPanels(serviceType=service, startRow=1000))
    .addPanels(self.workload(serviceType=service, startRow=2000))
    .addPanels(self.data(serviceType=service, startRow=3000)),
}
