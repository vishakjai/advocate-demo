local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local template = grafana.template;
local row = grafana.row;
local panel = import 'grafana/time-series/panel.libsonnet';

local selector = {
  environment: '$environment',
  grpc_method: '$method',
  fqdn: { re: '$fqdn' },
};

// Creating custom timeseries panel because panel.timeseries uses graph rather than timeseries type, and it does not support all functionalities we want.
local customTimeseriesPanel(
  title,
  expr,
  max=null,
  unit='',
  decimals=null,
  legendFormat='',
  thresholds=null,
  drawStyle='line',
  fillOpacity=10,
  lineWidth=1,
  legendCalcs=[],
  description='',
  thresholdStyle='off',
  scaleDistribution='linear'
      ) = {
  type: 'timeseries',
  title: title,
  description: description,
  datasource: {
    uid: '$PROMETHEUS_DS',
  },
  fieldConfig: {
    defaults: {
      custom: {
        drawStyle: drawStyle,
        lineInterpolation: 'linear',
        barAlignment: 0,
        lineWidth: lineWidth,
        fillOpacity: fillOpacity,
        gradientMode: 'none',
        spanNulls: true,
        insertNulls: false,
        showPoints: 'never',
        pointSize: 5,
        axisPlacement: 'auto',
        axisColorMode: 'text',
        axisBorderShow: false,
        // Use a conditional expression for scaleDistribution, here if condition is not satisfied key becomes null which is then ignored.
        [if scaleDistribution == 'log' then 'scaleDistribution']: {
          type: 'log',
          log: 10,
        },
        [if scaleDistribution == 'linear' then 'scaleDistribution']: {
          type: 'linear',
        },
        axisCenteredZero: false,
        thresholdsStyle: {
          mode: thresholdStyle,
        },
      },
      color: {
        mode: 'palette-classic',
      },
      mappings: [],
      thresholds: thresholds,
      links: [],
      min: 0,
      max: max,
      unit: unit,
      decimals: decimals,
    },
    overrides: [],
  },
  options: {
    legend: {
      showLegend: true,
      displayMode: 'list',
      placement: 'bottom',
      calcs: legendCalcs,
    },
  },
  targets: [
    {
      datasource: {
        type: 'prometheus',
        uid: '$PROMETHEUS_DS',
      },
      expr: expr,
      format: 'time_series',
      intervalFactor: 2,
      range: true,
      legendFormat: legendFormat,
    },
  ],
};

basic.dashboard(
  'Gitaly Feature Status',
  tags=['gitaly', 'type:gitaly'],
)
.addTemplate(template.new(
  'method',
  '$PROMETHEUS_DS',
  'label_values(gitaly:grpc_server_handled_total:rate1m{env="$environment"}, grpc_method)',
  refresh='load',
  sort=1,
))
.addTemplate(template.new(
  'fqdn',
  '$PROMETHEUS_DS',
  'label_values(gitaly:grpc_server_handled_total:rate1m{env="$environment"}, fqdn)',
  refresh='load',
  sort=1,
  multi=true,
  includeAll=true,
  allValues='.*',
))
.addPanel(
  row.new(title='Feature Status'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Feature Flags',
        query=|||
          sum(rate(gitaly_feature_flag_checks_total{%(selector)s}[$__rate_interval])) by (flag, enabled)
        ||| % { selector: selectors.serializeHash({ env: '$environment', fqdn: { re: '$fqdn' } }) },
        legendFormat='{{flag}}: {{enabled}}',
      ),
      customTimeseriesPanel(
        title='Success Ratio (SLA)',
        expr=|||
          1 - (sum(gitaly:grpc_server_handled_total:error_rate1m{%(selector)s}) without (grpc_code) / gitaly:grpc_server_handled_total:rate1m{%(selector)s})
        ||| % { selector: selectors.serializeHash(selector) },
        max=1,
        unit='percentunit',
        decimals=2,
        legendFormat='stage: {{stage}}, shard: {{shard}}',
        thresholds={
          mode: 'absolute',
          steps: [
            { color: 'red', value: null },
            { color: 'orange', value: 0.9 },
            { color: 'transparent', value: 0.999 },
          ],
        },
        thresholdStyle='line+area',
        legendCalcs=['mean', 'min'],
        description='This graph represents the percentage of requests that succeed.',
      ),
    ], cols=1, rowHeight=10, startRow=1
  )
)
.addPanels(
  layout.grid([
    customTimeseriesPanel(
      title='Total Rate',
      expr=|||
        sum(gitaly:grpc_server_handled_total:rate1m{%(selector)s}) by (grpc_method)
      ||| % { selector: selectors.serializeHash(selector) },
      unit='reqps',
      legendFormat='{{grpc_method}}',
      legendCalcs=['mean', 'max'],
    ),
    customTimeseriesPanel(
      title='Success Rate',
      expr=|||
        sum(gitaly:grpc_server_handled_total:rate1m{%(selector)s} - sum(gitaly:grpc_server_handled_total:error_rate1m{%(selector)s}) without (grpc_code))
      ||| % { selector: selectors.serializeHash(selector) },
      unit='reqps',
      legendFormat='Success',
      legendCalcs=['mean', 'max'],
    ),
    customTimeseriesPanel(
      title='Failure Rate',
      expr=|||
        sum(gitaly:grpc_server_handled_total:error_rate1m{%(selector)s}) by (grpc_code)
      ||| % { selector: selectors.serializeHash(selector) },
      unit='reqps',
      legendFormat='{{grpc_code}}',
      legendCalcs=['mean', 'max'],
    ),
  ], cols=3, rowHeight=5, startRow=100)
)
.addPanels(
  layout.grid([
    customTimeseriesPanel(
      title='Latency',
      expr='',
      unit='ms',
      fillOpacity=0,
      scaleDistribution='log',
      legendCalcs=['mean'],
    ) + {
      targets: [
        {
          expr: |||
            histogram_quantile(0.99, sum(gitaly:grpc_server_handling_seconds_bucket:rate1m{%(selector)s}) by (le)) * 1000
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: 'P99',
        },
        {
          expr: |||
            histogram_quantile(0.95, sum(gitaly:grpc_server_handling_seconds_bucket:rate1m{%(selector)s}) by (le)) * 1000
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: 'P95',
        },
        {
          expr: |||
            histogram_quantile(0.5, sum(gitaly:grpc_server_handling_seconds_bucket:rate1m{%(selector)s}) by (le)) * 1000
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: 'P50',
        },
        {
          expr: |||
            avg(1000 * avg(gitaly:grpc_server_handling_seconds:avg5m{%(selector)s}))
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: 'mean',
        },
      ],
    },
    customTimeseriesPanel(
      title='Per-Git-command latency',
      expr=|||
        sum by(subcmd) (
          rate(
            gitaly_command_cpu_seconds_total{%(selector)s}[$__rate_interval]
          )
        )
      ||| % { selector: selectors.serializeHash(selector) },
      legendFormat='{{subcmd}}',
      unit='s',
      fillOpacity=0,
      scaleDistribution='log',
    ),
    customTimeseriesPanel(
      title='Calls per Second per Tier',
      expr='',
      unit='reqps',
      fillOpacity=0,
      lineWidth=2,
      legendCalcs=['mean', 'max', 'min'],
    ) + {
      targets: [
        {
          expr: |||
            sum(rate(grpc_server_handled_total{%(selector)s}[1m]))
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: 'now',
        },
        {
          expr: |||
            sum(rate(grpc_server_handled_total{%(selector)s}[1m] offset 1w))
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: 'last week',
        },
      ],
    },
    customTimeseriesPanel(
      title='Call Rate vs 1 week prior (log₁₀)',
      expr='',
      unit='reqps',
      scaleDistribution='log',
    ) + {
      targets: [
        {
          expr: |||
            sum(gitaly:grpc_server_handled_total:rate1m {%(selector)s})
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: 'rate (1m)',
        },
        {
          expr: |||
            sum(gitaly:grpc_server_handled_total:rate1m{%(selector)s} offset 1w)
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: 'rate (1m) -1w',
        },
      ],
    },
    customTimeseriesPanel(
      title='Server Breakdown',
      expr=|||
        sum(rate(grpc_server_handled_total{%(selector)s}[10m])) BY (fqdn)
      ||| % { selector: selectors.serializeHash(selector) },
      unit='reqps',
      fillOpacity=0,
      legendFormat='{{ fqdn }}',
    ),
    customTimeseriesPanel(
      title='12 hour error anomaly rates (log₁₀)',
      expr='',
      unit='short',
      scaleDistribution='log',
    ) + {
      targets: [
        {
          expr: |||
            gitaly:grpc_server_handled_total:error_rate1m{%(selector)s}
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: '{{ grpc_code }}',
        },
        {
          expr: |||
            gitaly:grpc_server_handled_total:error_avg_rate12h{%(selector)s}
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: '12 hour avg',
        },
        {
          expr: |||
            gitaly:grpc_server_handled_total:error_avg_rate12h{%(selector)s} + gitaly:grpc_server_handled_total:error_rate1m_stddev_over_time12h{%(selector)s}
          ||| % { selector: selectors.serializeHash(selector) },
          legendFormat: '12 hour 2σ',
        },
      ],
    },
  ], cols=1, rowHeight=10, startRow=200)
)
.trailer()
