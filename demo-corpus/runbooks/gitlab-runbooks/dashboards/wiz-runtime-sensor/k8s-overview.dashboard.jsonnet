local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Kubernetes Overview',
  tags=['wiz-sensor-k8s', 'infrasec', 'wiz']
)

.addPanels(
  layout.grid([
    panel.timeSeries(
      title='Wiz Sensor: Pod CPU Usage',
      query=|||
        sum by (cluster, pod) (topk(2,rate(container_cpu_usage_seconds_total{env='$environment', container='wiz-sensor'}[$__rate_interval])))
      |||,
      legendFormat='{{ cluster }} - {{ pod }}',
    ),
    panel.timeSeries(
      title='Wiz Sensor: Memory Usage',
      query=|||
        sum by (cluster,pod) (topk(5,container_memory_usage_bytes{env="$environment",namespace="wiz-sensor",container="wiz-sensor"}))
      |||,
      legendFormat='{{ cluster - pod }}'
    ),

    panel.timeSeries(
      title='Wiz Sensor: OOM Kills',
      query=|||
        topk(5,(container_oom_events_total{env='$environment', container='wiz-sensor'}))
      |||,
      legendFormat='{cluster="{{cluster}}", pod={{pod}}}'
    ),

    panel.timeSeries(
      title='Wiz Sensor: Write IO',
      query=|||
        sum by (cluster, pod) (rate(container_fs_writes_total{env="$environment",container="wiz-sensor"}[$__rate_interval]))
      |||,
      legendFormat='{{cluster}} {{pod}}',
    ),

    panel.timeSeries(
      title='Wiz Sensor: Read IO',
      query=|||
        sum by (cluster, pod) (rate(container_fs_reads_total{env="$environment",container="wiz-sensor"}[$__rate_interval]))
      |||,
      legendFormat='{{cluster}} {{pod}}',
    ),

    panel.timeSeries(
      title='Wiz Sensor: Network IO'
    )
    .addTarget({
      expr: 'sum by (cluster,pod) (topk(5,\n  rate(\n    container_network_transmit_bytes_total{\n      env="$environment",namespace="wiz-sensor"\n    }[$__rate_interval]\n  )))\n',
      legendFormat: 'send {{ cluster }} {{ pod }}',
      intervalfactor: 1,
      refId: 'A',
      datasource: '$PROMETHEUS_DS',
    })

    .addTarget({
      expr: 'sum by (cluster,pod) (topk(5,\n  rate(\n    container_network_receive_bytes_total{\n      env="$environment",namespace="wiz-sensor"\n    }[$__rate_interval]\n  )))\n',
      legendFormat: 'receive {{ cluster }} {{ pod }}',
      intervalfactor: 1,
      refId: 'B',
      datasource: '$PROMETHEUS_DS',
    }),
  ])
)
