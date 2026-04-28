local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Linux Hosts',
  tags=['wiz-sensor', 'wiz-sensor-linux'],
)

.addPanels(
  layout.grid([
    panel.timeSeries(
      title='CPU User Usage',
      query=|||
        rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",environment="$environment",mode="user",fqdn="$node"}[1h])
      |||,
      legendFormat='user',
    ),

    panel.timeSeries(
      title='CPU System Usage',
      query=|||
        rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",environment="$environment",mode="system",fqdn="$node"}[1h])
      |||,
      legendFormat='system'
    ),

    panel.timeSeries(
      title='Wiz Sensor Memory Usage',
      query=|||
        namedprocess_namegroup_memory_bytes{groupname="wiz-sensor",memtype="resident",environment="$environment",fqdn="$node"}
      |||,
      legendFormat='Memory Usage',
    ),

    panel.timeSeries(
      title='Write IO',
      query=|||
        rate(namedprocess_namegroup_write_bytes_total{groupname="wiz-sensor",environment="$environment",fqdn="$node"}[2h])
      |||,
      legendFormat='Write IO',
    ),

    panel.timeSeries(
      title='Read IO',
      query=|||
        topk(5,rate(namedprocess_namegroup_read_bytes_total{groupname="wiz-sensor",environment="$environment",fqdn="$node"}[2h]))
      |||,
      legendFormat='Read IO',
    ),
  ])
)
+
{
  templating+: {
    list+: [
      {
        name: 'node',
        type: 'query',
        datasource: '$PROMETHEUS_DS',
        query: 'label_values(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor", env="$environment"},fqdn)',
        current: {
          text: 'default_value',
          value: 'default_value',
        },
        refresh: 1,
        includeAll: false,
        label: 'Host',
        hide: 0,
        sort: 0,
        regex: '',
      },
    ],
  },
}
