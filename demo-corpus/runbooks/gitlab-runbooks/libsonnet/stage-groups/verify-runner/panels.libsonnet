local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local heatmapPanel = grafana.heatmapPanel;
local promQuery = import 'grafana/prom_query.libsonnet';

local target = import 'grafana/time-series/target.libsonnet';
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local pc = g.panel.pieChart;

local heatmap(
  title,
  query,
  interval='$__rate_interval',
  intervalFactor=3,
  color_mode='opacity',  // alowed are: opacity, spectrum
  color_cardColor='#FA6400',  // used when color_mode='opacity' is set
  color_colorScheme='Oranges',  // used when color_mode='spectrum' is set
  color_exponent=0.5,
  legend_show=false,
  description='',
      ) =
  heatmapPanel.new(
    title=title,
    description=description,
    datasource='$PROMETHEUS_DS',
    legend_show=legend_show,
    yAxis_format='s',
    dataFormat='tsbuckets',
    yAxis_decimals=2,
    color_mode=color_mode,
    color_cardColor=color_cardColor,
    color_colorScheme=color_colorScheme,
    color_exponent=color_exponent,
    cards_cardPadding=1,
    cards_cardRound=2,
    tooltipDecimals=3,
    tooltip_showHistogram=true,
  )
  .addTarget(
    promQuery.target(
      query,
      format='time_series',
      legendFormat='{{le}}',
      interval=interval,
      intervalFactor=intervalFactor,
    ) + {
      dsType: 'influxdb',
      format: 'heatmap',
      orderByTime: 'ASC',
      groupBy: [
        {
          params: ['$__rate_interval'],
          type: 'time',
        },
        {
          params: ['null'],
          type: 'fill',
        },
      ],
      select: [
        [
          {
            params: ['value'],
            type: 'field',
          },
          {
            params: [],
            type: 'mean',
          },
        ],
      ],
    }
  );

local pieChart(
  title,
  query,
  datasource='$PROMETHEUS_DS',
  legendFormat='',
  format='time_series',
  instant=true,
  interval='1m',
  intervalFactor=1,
  reducerFunction='lastNotNull',
  description='',
  stableId=null,
  pieType='donut',
  legendShow=true,
  legendAsTable=true,
  legendAtRight=true,
  unit='short',
      ) =
  local datasourceType =
    if datasource == '$PROMETHEUS_DS' then
      'prometheus'
    else
      error 'unsupported data source: ' + datasource;

  local legendDisplayMode =
    if legendAsTable then
      'table'
    else
      'list';

  local legendPlacement = if legendAtRight then
    'right'
  else
    'bottom';

  pc.new(title)
  + pc.panelOptions.withDescription(description)
  + pc.datasource.withType(datasourceType)
  + pc.datasource.withUid(datasource)
  + pc.standardOptions.withUnit(unit)
  + pc.options.withPieType(pieType)
  + pc.options.reduceOptions.withCalcs(reducerFunction)
  + pc.options.legend.withShowLegend(legendShow)
  + pc.options.legend.withDisplayMode(legendDisplayMode)
  + pc.options.legend.withPlacement(legendPlacement)
  + pc.options.legend.withValues(['value', 'percent'])
  + {
    targets+: [
      target.prometheus(
        query,
        legendFormat=legendFormat,
        format=format,
        instant=instant,
        interval=interval,
        intervalFactor=intervalFactor
      ),
    ],
  }
  + (if stableId != null then { stableId: stableId } else {});

{
  heatmap:: heatmap,
  pieChart:: pieChart,
}
