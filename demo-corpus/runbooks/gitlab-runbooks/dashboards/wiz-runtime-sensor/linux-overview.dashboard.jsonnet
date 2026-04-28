local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local panel = import 'grafana/time-series/panel.libsonnet';
local templates = import 'grafana/templates.libsonnet';

basic.dashboard(
  'Linux Overview',
  tags=['wiz-sensor', 'wiz-sensor-linux'],
)

.addPanels(
  layout.grid([
    {
      type: 'gauge',
      title: 'System Coverage',
      datasource: '$PROMETHEUS_DS',
      targets: [
        {
          editorMode: 'code',
          exemplar: false,
          expr: 'count by (environment) ( count by(fqdn,environment)  (namedprocess_namegroup_num_threads{groupname="wiz-sensor", environment=~"gprd|gstg|pre|ops"}>0)) / count by (environment) (node_boot_time_seconds{namespace="",environment=~"gprd|gstg|pre|ops"}) *100\n',
          instant: true,
          legendFormat: '__auto',
          range: false,
          refId: 'A',
        },
      ],
      options: {
        reduceOptions: {
          values: false,
          calcs: ['lastNotNull'],
          fields: '',
        },
        showThresholdLabels: false,
        showThresholdMarkers: false,
      },
      fieldConfig: {
        defaults: {
          thresholds: {
            mode: 'precentage',
            steps: [
              { value: 0, color: 'red' },
              { value: 100, color: 'green' },
            ],
          },
          min: 0,
          max: 100,
          unit: 'percent',
        },
      },
    },

    {
      type: 'table',
      title: 'Nodes without Wiz Sensor',
      fieldConfig: {
        defaults: {
          custom: {
            align: 'auto',
            cellOptions: {
              type: 'auto',
            },
            inspect: true,
            filterable: true,
          },
          mappings: [],
          thresholds: {
            mode: 'absolute',
            steps: [
              {
                color: 'green',
                value: null,
              },
              {
                color: 'red',
                value: 80,
              },
            ],
          },
          color: {
            mode: 'thresholds',
          },
        },
        overrides: [],
      },
      transformations: [
        {
          id: 'reduce',
          options: {
            labelsToFields: true,
            reducers: [
              'max',
            ],
          },
        },
        {
          id: 'reduce',
          options: {
            includeTimeField: false,
            mode: 'reduceFields',
            reducers: [],
          },
        },
        {
          id: 'groupBy',
          options: {
            fields: {
              fqdn: {
                aggregations: [],
                operation: 'groupby',
              },
            },
          },
        },
      ],
      targets: [
        {
          editorMode: 'code',
          exemplar: false,
          expr: 'group by (fqdn) (node_boot_time_seconds{environment="$environment",namespace=""}) unless (group by (fqdn) (namedprocess_namegroup_num_threads{groupname="wiz-sensor", environment="$environment"}>0))',
          instant: true,
          range: false,
          refId: 'A',
        },
      ],
    },

    {
      type: 'stat',
      title: 'Total Hosts',
      fieldConfig: {
        defaults: {
          mappings: [],
          thresholds: {
            mode: 'absolute',
            steps: [
              {
                color: 'green',
                value: null,
              },
            ],
          },
          color: {
            mode: 'thresholds',
          },
        },
        overrides: [
        ],
      },
      targets: [
        {
          editorMode: 'code',
          expr: 'count(node_boot_time_seconds{environment="$environment",namespace=""})\n',
          instant: false,
          range: true,
          refId: 'A',
        },
      ],
      options: {
        graphMode: 'none',
        reduceOptions: {
          values: false,
          calcs: [
            'lastNotNull',
          ],
          fields: '',
        },
      },
    },

    {
      type: 'stat',
      title: 'Host with wiz-sensor',
      fieldConfig: {
        defaults: {
          mappings: [],
          thresholds: {
            mode: 'absolute',
            steps: [
              {
                color: 'green',
                value: null,
              },
            ],
          },
          color: {
            mode: 'thresholds',
          },
        },
        overrides: [],
      },
      targets: [
        {
          editorMode: 'code',
          expr: 'count(count by(fqdn) (namedprocess_namegroup_num_threads{groupname="wiz-sensor", environment="$environment"}>0)) or vector(0)',
          instant: false,
          legendFormat: '__auto',
          range: true,
          refId: 'A',
        },
      ],
      options: {
        graphMode: 'none',
        reduceOptions: {
          values: false,
          calcs: [
            'lastNotNull',
          ],
          fields: '',
        },
      },
    },

    panel.timeSeries(
      title='top5 CPU User Usage',
      query=|||
        topk(5,rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",environment="$environment",mode="user"}[1h]))
      |||,
      legendFormat='{{fqdn}}',
    ),
    panel.timeSeries(
      title='top5 CPU System Usage',
      query=|||
        topk(5,rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",environment="$environment",mode="system"}[1h]))
      |||,
      legendFormat='{{fqdn}}'
    ),
    panel.timeSeries(
      title='wiz-sensor fleet CPU Usage'
    )
    .addTarget({
      expr: 'avg by (env) (rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",environment="$environment",mode="user"}[5m]))',
      legendFormat: 'user',
      range: true,
      refId: 'A',
      datasource: '$PROMETHEUS_DS',
    })

    .addTarget({
      expr: 'avg by (env) (rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",environment="$environment",mode="system"}[5m]))',
      legendFormat: 'system',
      range: true,
      refId: 'B',
      datasource: '$PROMETHEUS_DS',
    })

    .addTarget({
      expr: 'avg by (env) (rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",environment="$environment"}[5m]))',
      legendFormat: 'total',
      range: true,
      refId: 'C',
      datasource: '$PROMETHEUS_DS',
    }),

    panel.timeSeries(
      title='top5 write IO',
      query=|||
        topk(5,rate(namedprocess_namegroup_write_bytes_total{groupname="wiz-sensor",environment="$environment"}[2h]))
      |||,
      legendFormat='{{fqdn}}',
    ),

    panel.timeSeries(
      title='top5 read IO',
      query=|||
        topk(5,rate(namedprocess_namegroup_read_bytes_total{groupname="wiz-sensor",environment="$environment"}[2h]))
      |||,
      legendFormat='{{fqdn}}',
    ),

    panel.timeSeries(
      title='wiz-sensor fleet IO'
    )
    .addTarget({
      expr: 'sum by (env) (rate(namedprocess_namegroup_write_bytes_total{groupname="wiz-sensor",environment="$environment"}[5m]))',
      legendFormat: 'write',
      intervalfactor: 1,
      refId: 'A',
      datasource: '$PROMETHEUS_DS',
    })

    .addTarget({
      expr: 'sum by (env) (rate(namedprocess_namegroup_read_bytes_total{groupname="wiz-sensor",environment="$environment"}[5m]))',
      legendFormat: 'read',
      intervalfactor: 1,
      refId: 'B',
      datasource: '$PROMETHEUS_DS',
    }),

    panel.timeSeries(
      title='top5 memory usage',
      query=|||
        topk(5,namedprocess_namegroup_memory_bytes{groupname="wiz-sensor",memtype="resident",environment="$environment"})
      |||,
      legendFormat='{{fqdn}}',
    ),

    panel.timeSeries(
      title='Average memory per node',
      query=|||
        sum(namedprocess_namegroup_memory_bytes{groupname="wiz-sensor", environment="$environment"}) / count(up{environment="$environment"})
      |||,
      legendFormat='Average memory per node',
    ),
  ])
)
