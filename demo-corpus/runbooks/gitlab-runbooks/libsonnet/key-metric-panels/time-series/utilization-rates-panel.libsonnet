local platformLinks = import '../../gitlab-dashboards/platform_links.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local utilizationRatesPanel(
  serviceType,
  selectorHash,
  compact=false,
  stableId=stableId,
  linewidth=if compact then 1 else 2,
      ) =
  local hasShardSelector = std.objectHas(selectorHash, 'shard');
  local aggregationLabels = if !hasShardSelector then ['component'] else ['component', 'shard'];
  local legendFormat = if !hasShardSelector then
    '{{ component }} component'
  else
    '{{ component }} component - {{ shard }} shard';

  local formatConfig = {
    serviceType: serviceType,
    selector: selectors.serializeHash(selectorHash { type: serviceType }),
    aggregationLabels: std.join(', ', aggregationLabels),
  };
  panel.basic(
    title='Saturation',
    description='Saturation is a measure of what ratio of a finite resource is currently being utilized. Lower is better.',
    legend_show=!compact,
    linewidth=linewidth,
    unit='percentunit',
    stableId=stableId,
  )
  .addTarget(  // Primary metric
    target.prometheus(
      |||
        max(
          max_over_time(
            gitlab_component_saturation:ratio{%(selector)s}[$__interval]
          )
        ) by (%(aggregationLabels)s)
      ||| % formatConfig,
      legendFormat=legendFormat,
    )
  )
  .addYaxis(
    max=1,
    label=if compact then '' else 'Saturation %',
  )
  + {
    links+: platformLinks.saturationDetails(serviceType),
  }
;

{
  panel:: utilizationRatesPanel,
}
