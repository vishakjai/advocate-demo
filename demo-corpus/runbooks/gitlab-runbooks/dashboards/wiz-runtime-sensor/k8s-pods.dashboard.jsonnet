local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Kubernetes Pods',
  tags=['wiz-sensor-k8s', 'infrasec', 'wiz']
)
.addPanels(
  layout.grid([
    panel.timeSeries(
      title='Wiz Sensor: Pod CPU Usage',
      query=|||
        sum by (pod) (rate(container_cpu_usage_seconds_total{env='$environment', container='wiz-sensor',cluster="$cluster",pod="$pod"}[$__rate_interval]))
      |||,
      legendFormat='{{ pod }}',
    ),

    panel.timeSeries(
      title='Wiz Sensor: Memory Usage',
      query=|||
        sum by (pod) (container_memory_usage_bytes{env="$environment",namespace="wiz-sensor",cluster="$cluster",pod="$pod",container="wiz-sensor"})
      |||,
      legendFormat='Memory Usage',
    ),

    panel.timeSeries(
      title='Wiz Sensor: Read IO',
      query=|||
        sum by (pod) (rate(container_fs_reads_total{env="$environment",container="wiz-sensor",cluster="$cluster",pod="$pod"}[$__rate_interval]))
      |||,
      legendFormat='Read IO',
    ),

    panel.timeSeries(
      title='Wiz Sensor: Write IO',
      query=|||
        sum by (pod) (rate(container_fs_writes_total{env="$environment",container="wiz-sensor",cluster="$cluster",pod="$pod"}[$__rate_interval]))
      |||,
      legendFormat='Write IO',
    ),

    panel.timeSeries(
      title='Wiz Sensor: Network IO'
    )
    .addTarget({
      expr: 'sum by (pod) (\n  rate(\n    container_network_transmit_bytes_total{\n      env="$environment",namespace="wiz-sensor",cluster="$cluster",pod="$pod"\n    }[$__rate_interval]\n  ))\n',
      legendFormat: 'send {{ cluster }} {{ pod }}',
      intervalfactor: 1,
      refId: 'A',
      datasource: '$PROMETHEUS_DS',
    })

    .addTarget({
      expr: 'sum by (pod) (\n  rate(\n    container_network_receive_bytes_total{\n      env="$environment",namespace="wiz-sensor",cluster="$cluster",pod="$pod"\n    }[$__rate_interval]\n  ))',
      legendFormat: 'receive {{ cluster }} {{ pod }}',
      intervalfactor: 1,
      refId: 'B',
      datasource: '$PROMETHEUS_DS',
    }),

  ])
)
+
{
  templating+: {
    list+: [
      {
        name: 'cluster',
        type: 'query',
        datasource: '$PROMETHEUS_DS',
        query: 'label_values(container_memory_usage_bytes{container="wiz-sensor", env="$environment"},cluster)',
        current: {
          text: 'default_value',
          value: 'default_value',
        },
        refresh: 1,
        includeAll: false,
        label: 'Cluster',
        hide: 0,
        sort: 0,
        regex: '',
      },
      {
        name: 'pod',
        type: 'query',
        datasource: '$PROMETHEUS_DS',
        query: 'label_values(container_memory_usage_bytes{container="wiz-sensor", env="$environment", cluster="$cluster"},pod)',
        current: {
          text: 'default_value',
          value: 'default_value',
        },
        refresh: 1,
        includeAll: false,
        label: 'Pod',
        hide: 0,
        sort: 0,
        regex: '',
      },
    ],
  },
}
