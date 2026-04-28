local sliPromQL = import '../sli_promql.libsonnet';
local override = import 'grafana/time-series/override.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local defaultOperationRateDescription = 'The operation rate is the sum total of all requests being handle for all components within this service. Note that a single user request can lead to requests to multiple components. Higher is busier.';

local genericOperationRatePanel(
  title,
  description=null,
  compact=false,
  stableId,
  linewidth=null,
  legend_show=null,
      ) =
  panel.basic(
    title,
    linewidth=if linewidth == null then if compact then 1 else 2 else linewidth,
    description=if description == null then defaultOperationRateDescription else description,
    legend_show=if legend_show == null then !compact else legend_show,
    stableId=stableId,
  )
  .addYaxis(
    min=0,
    label=if compact then '' else 'Operations per Second',
  );

local operationRatePanel(
  title,
  aggregationSet,
  selectorHash,
  stableId,
  legendFormat=null,
  compact=false,
  includePredictions=false,
  includeLastWeek=true,
  expectMultipleSeries=false,
      ) =
  local selectorHashWithExtras = selectorHash + aggregationSet.selector;

  local panel =
    genericOperationRatePanel(
      title,
      compact=compact,
      stableId=stableId,
      linewidth=if expectMultipleSeries then 1 else 2
    )
    .addTarget(  // Primary metric
      target.prometheus(
        sliPromQL.opsRateQuery(aggregationSet, selectorHashWithExtras, range='$__interval'),
        legendFormat=legendFormat,
      )
    );

  local panelWithSeriesOverrides = if !expectMultipleSeries then
    panel.addSeriesOverride(override.goldenMetric(legendFormat))
  else
    panel;

  local panelWithLastWeek = if !expectMultipleSeries && includeLastWeek then
    panelWithSeriesOverrides
    .addTarget(  // Last week
      target.prometheus(
        sliPromQL.opsRateQuery(aggregationSet, selectorHashWithExtras, range=null, offset='1w'),
        legendFormat='last week',
      )
    )
    .addSeriesOverride(override.lastWeek)
  else
    panelWithSeriesOverrides;

  local panelWithPredictions = if !expectMultipleSeries && includePredictions then
    panelWithLastWeek
    .addTarget(
      target.prometheus(
        sliPromQL.opsRate.serviceOpsRatePrediction(selectorHashWithExtras, 1),
        legendFormat='upper normal',
      ),
    )
    .addTarget(
      target.prometheus(
        sliPromQL.opsRate.serviceOpsRatePrediction(selectorHashWithExtras, -1),
        legendFormat='lower normal',
      ),
    )
    .addSeriesOverride(override.upper)
    .addSeriesOverride(override.lower)
  else
    panelWithLastWeek;

  panelWithPredictions;

{
  panel:: operationRatePanel,
}
