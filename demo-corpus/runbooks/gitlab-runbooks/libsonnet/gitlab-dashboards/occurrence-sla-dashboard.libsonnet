local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local availabilityPromql = import 'gitlab-availability/availability-promql.libsonnet';
local grafanaCalHeatmap = import 'grafana-cal-heatmap-panel/panel.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local strings = import 'utils/strings.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local templateServiceName(service) =
  std.strReplace(service, '-', '_');
local milisecondsQuery(ratioQuery) =
  |||
    (
      1 - (
        %s
      )
    ) * $__range_ms
  ||| % [strings.indent(ratioQuery, 4)];
local budgetMinutesColor = {
  color: 'light-blue',
  value: null,
};

local clampRatio(ratioQuery) =
  |||
    clamp_max(
      clamp_min(
        %s,
        0
      ),
      1
    )
  ||| % [strings.indent(ratioQuery, 4)];

local serviceSlaRow(availability, service, sloThreshold, selector) =
  local slaAvailabilityRatio = clampRatio(
    availability.availabilityRatio(
      aggregationLabels=[],
      selector=selector,
      services=[service],
      range='$__range',
    )
  );
  [
    basic.slaStats(
      title='%s availability' % [service],
      query=slaAvailabilityRatio,
    ),
    basic.slaStats(
      title='',
      query=milisecondsQuery(slaAvailabilityRatio),
      legendFormat='',
      displayName='Budget Spent',
      decimals=1,
      unit='ms',
      colors=[budgetMinutesColor],
      colorMode='value',
    ),
    panel.slaTimeSeries(
      title='%s SLA over time period' % [service],
      description='Availability over time, higher is better.',
      yAxisLabel='SLA',
      query=clampRatio(availability.availabilityRatio(
        aggregationLabels=[],
        selector=selector,
        services=[service],
        range='$__interval',
      )),
      legendFormat='%s SLA' % [service],
      legend_show=false
    ),
  ];

local overallSlaRow(availability, keyServiceWeights, sloThreshold, selector) =
  local dashboardServiceWeights = {
    [service]: '$%s_weight' % [templateServiceName(service)]
    for service in std.objectFields(keyServiceWeights)
  };
  local slaAvailabilityRatio = availability.weightedAvailabilityQuery(dashboardServiceWeights, selector, '$__range');
  [
    basic.slaStats(
      title='Overall availability',
      query=slaAvailabilityRatio,
    ),
    basic.slaStats(
      title='',
      query=milisecondsQuery(slaAvailabilityRatio),
      legendFormat='',
      displayName='Budget Spent',
      decimals=1,
      unit='ms',
      colors=[budgetMinutesColor],
      colorMode='value',
    ),
    panel.slaTimeSeries(
      title='Overall GitLab.com SLA over time period',
      description='Availability over time, higher is better.',
      yAxisLabel='SLA',
      query=clampRatio(availability.weightedAvailabilityQuery(dashboardServiceWeights, selector, '$__interval')),
      legendFormat='Overall SLA',
      legend_show=false
    ),
  ];

local dashboard(availability, keyServiceWeights, slo, selector, sortedServices) =
  local serviceWeightTemplates = [
    template.custom(
      name='%s_weight' % [templateServiceName(service)],
      query='0,1,5',
      current='%s' % [keyServiceWeights[service]]
    )
    for service in sortedServices
  ];
  basic.dashboard(
    'Occurence SLAs',
    tags=['general', 'slas', 'service-levels'],
    includeStandardEnvironmentAnnotations=false,
    time_from='now-1M/M',
    time_to='now-1d/d',
  )
  .addTemplates(serviceWeightTemplates)
  .addPanels(
    layout.titleRowWithPanels(
      title='Overall GitLab availability',
      collapse=false,
      startRow=5,
      panels=layout.columnGrid(
        rowsOfPanels=[overallSlaRow(availability, keyServiceWeights, slo, selector)],
        columnWidths=[4, 4, 16],
        rowHeight=5,
        startRow=10
      ),
    )
  ).addPanels(
    layout.titleRowWithPanels(
      title='GitLab Primary Service Availability',
      collapse=false,
      startRow=15,
      panels=layout.columnGrid(
        rowsOfPanels=[
          serviceSlaRow(availability, service, slo, selector)
          for service in sortedServices
        ],
        columnWidths=[4, 4, 16],
        rowHeight=5,
        startRow=15
      ),
    ),
  );

{
  dashboard(keyServiceWeights, aggregationSet, slo, extraSelector={}, sortedServices=std.objectFields(keyServiceWeights)):
    local availability = availabilityPromql.new(keyServiceWeights, aggregationSet);
    dashboard(availability, keyServiceWeights, slo, extraSelector, sortedServices),
}
