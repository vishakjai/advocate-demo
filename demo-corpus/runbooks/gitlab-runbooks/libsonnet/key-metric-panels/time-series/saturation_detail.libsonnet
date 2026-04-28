local override = import './grafana/time-series/override.libsonnet';
local panel = import './grafana/time-series/panel.libsonnet';
local target = import './grafana/time-series/target.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local maxOverTime(query) =
  'max_over_time(%(query)s[$__interval])' % { query: query };

local saturationPanel(title, description, component, linewidth=1, query=null, legendFormat=null, selector=null, overTimeFunction=maxOverTime) =
  local formatConfig = {
    component: component,
    query: query,
    selector: selectors.serializeHash(selector),
  };

  local p = panel.basic(
    title=title,
    description=description,
    linewidth=linewidth,
    datasource='$PROMETHEUS_DS',
    legend_show=true,
    legend_min=true,
    legend_max=true,
    legend_current=true,
    legend_total=false,
    legend_avg=true,
    legend_alignAsTable=true,
    unit='percentunit',
  );

  local p2 = if query != null then
    p.addTarget(  // Primary metric
      target.prometheus(
        |||
          clamp_min(
            clamp_max(
              %(query)s
            ,1)
          ,0)
        ||| % formatConfig,
        legendFormat=legendFormat,
      )
    )
  else
    p;

  local recordingRuleQuery = 'gitlab_component_saturation:ratio{%(selector)s, component="%(component)s"}' % formatConfig;

  local recordingRuleQueryWithTimeFunction = if overTimeFunction != null then
    overTimeFunction(recordingRuleQuery)
  else
    recordingRuleQuery;

  p2.addTarget(  // Primary metric
    target.prometheus(
      |||
        clamp_min(
          clamp_max(
            max(
              %(recordingRuleQueryWithTimeFunction)s
            ) by (component)
          ,1)
        ,0)
      ||| % formatConfig { recordingRuleQueryWithTimeFunction: recordingRuleQueryWithTimeFunction },
      legendFormat='aggregated {{ component }}',
    )
  )
  .addTarget(  // 95th quantile for week
    target.prometheus(
      |||
        max(
          gitlab_component_saturation:ratio_quantile95_1w{%(selector)s, component="%(component)s"}
        )
      ||| % formatConfig,
      legendFormat='95th quantile for week {{ component }}',
    )
  )
  .addTarget(  // 99th quantile for week
    target.prometheus(
      |||
        max(
          gitlab_component_saturation:ratio_quantile99_1w{%(selector)s, component="%(component)s"}
        )
      ||| % formatConfig,
      legendFormat='99th quantile for week {{ component }}',
    )
  )
  .addTarget(  // Soft SLO
    target.prometheus(
      |||
        avg(slo:max:soft:gitlab_component_saturation:ratio{component="%(component)s"}) by (component)
      ||| % formatConfig,
      legendFormat='Soft SLO: {{ component }}',
    )
  )
  .addTarget(  // Hard SLO
    target.prometheus(
      |||
        avg(slo:max:hard:gitlab_component_saturation:ratio{component="%(component)s"}) by (component)
      ||| % formatConfig,
      legendFormat='Hard SLO: {{ component }}',
    )
  )
  .addYaxis(
    max=1,
    label='Saturation %',
  )
  .addSeriesOverride(override.softSlo)
  .addSeriesOverride(override.hardSlo)
  .addSeriesOverride(override.goldenMetric('/aggregated /', { linewidth: 2 },))
  .addSeriesOverride({
    alias: '/^95th quantile for week/',
    color: '#37872D',
    dashes: true,
    legend: true,
    linewidth: 1,
    dashLength: 4,
    nullPointMode: 'connected',
  })
  .addSeriesOverride({
    alias: '/^99th quantile for week/',
    color: '#56A64B',
    dashes: true,
    legend: true,
    linewidth: 2,
    dashLength: 4,
    nullPointMode: 'connected',
  }) {
    legend+: {
      sortDesc: true,
    },
  };

{
  panel: saturationPanel,
}
