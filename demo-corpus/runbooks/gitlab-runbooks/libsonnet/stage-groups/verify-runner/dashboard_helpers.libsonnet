local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prebuiltTemplates = import 'grafana/templates.libsonnet';
local runnersService = (import 'servicemetrics/metrics-catalog.libsonnet').getService('ci-runners');
local keyMetrics = import 'gitlab-dashboards/key_metrics.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';

local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;

local dashboardFilters = import './dashboard_filters.libsonnet';

local runnerServiceType = runnersService.type;

local underConstructionNote = layout.singleRow(
  [
    grafana.text.new(
      title='Under construction',
      mode='markdown',
      content=|||
        🚧 🦺 This dashboard is currently under construction 🦺 🚧

        Please come back later 🙂
      |||,
    ),
  ],
  rowHeight=3,
  startRow=0
);

local commonFilters = [
  dashboardFilters.type,
  dashboardFilters.shard,
];

local runnerServiceDashboardsLinks = [
  platformLinks.dynamicLinks('%s Detail' % runnerServiceType, 'type:%s' % runnerServiceType),
  platformLinks.dynamicLinks('%s Incident Dashboards' % runnerServiceType, '%s:incident-support' % runnerServiceType),
];

local dashboard(
  title,
  tags=[],
  time_from='now-3h/m',
  includeStandardEnvironmentAnnotations=true
      ) =
  basic.dashboard(
    title,
    tags=[
      'type:%s' % runnerServiceType,
      'managed',
    ] + tags,
    time_from=time_from,
    time_to='now/m',
    graphTooltip='shared_crosshair',
    includeStandardEnvironmentAnnotations=includeStandardEnvironmentAnnotations,
    includeEnvironmentTemplate=true,
  )
  .addTemplate(prebuiltTemplates.stage)
  .addTemplates(commonFilters)
  .trailer() + {
    links+: runnerServiceDashboardsLinks,
    addOverviewPanels(
      startRow=1000,
      showApdex=true,
      showErrorRatio=true,
      showOpsRate=false,
      showSaturationCell=true,
      showDashboardListPanel=false,
      compact=true,
      rowHeight=6,
    ):: self.addPanels(
      keyMetrics.headlineMetricsRow(
        runnerServiceType,
        startRow=startRow,
        selectorHash=dashboardFilters.selectorHash,
        showApdex=showApdex,
        showErrorRatio=showErrorRatio,
        showOpsRate=showOpsRate,
        showSaturationCell=showSaturationCell,
        showDashboardListPanel=showDashboardListPanel,
        compact=compact,
        rowHeight=rowHeight,
        rowTitle=null,
      )
    ),
    addRowGrid(
      title,
      startRow,
      collapse=false,
      panels=[],
      repeat=null,
    ):: self.addPanels(
      layout.rowGrid(
        title,
        panels,
        startRow=startRow,
        collapse=collapse,
        repeat=repeat,
      )
    ),
    addGrid(
      panels,
      startRow,
      rowHeight=6,
    ):: self.addPanels(
      layout.grid(
        panels=panels,
        cols=std.length(panels),
        startRow=startRow,
        rowHeight=rowHeight,
      )
    ),
    addUnderConstructionNote():: self.addPanels(
      underConstructionNote
    ),
  };

{
  dashboard:: dashboard,
  runnerServiceType:: runnerServiceType,
  runnerServiceDashboardsLinks:: runnerServiceDashboardsLinks,
}
