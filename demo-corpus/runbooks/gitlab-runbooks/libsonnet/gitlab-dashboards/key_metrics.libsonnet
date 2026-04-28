local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local singleMetricRow = import 'key-metric-panels/single-metric-row.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local panels = import 'key-metric-panels/time-series/panels.libsonnet';
local row = grafana.row;

local managedDashboardsForService(serviceType) =
  {
    type: 'dashlist',
    pluginVersion: '7.2.0',
    limit: 10,
    tags: [
      'type:' + serviceType,
    ],
    search: true,
    query: '',
    title: '',
    timeFrom: null,
    timeShift: null,
    recent: false,
    starred: false,
    headings: false,
    description: '',
    datasource: null,
  };

local countTrue(bool) = if bool then 1 else 0;

local getColumnWidths(
  showApdex=showApdex,
  showErrorRatio=showErrorRatio,
  showOpsRate=showOpsRate,
  showSaturationCell=showSaturationCell,
  showDashboardListPanel=showDashboardListPanel
      ) =
  local dashboardPanelWidth = 3;
  local width = 24 - (if showDashboardListPanel then dashboardPanelWidth else 0);
  local mainPanelCount = countTrue(showApdex) + countTrue(showErrorRatio) + countTrue(showOpsRate) + countTrue(showSaturationCell);

  local gap = width % mainPanelCount;
  local unfilledWidth = std.floor(width / mainPanelCount);

  local c(bool, priority) =
    if bool then
      local extra = if gap > priority then 1 else 0;
      [unfilledWidth + extra]
    else
      [];

  c(showApdex, 2) + c(showErrorRatio, 3) + c(showOpsRate, 1) + c(showSaturationCell, 0) + if showDashboardListPanel then [dashboardPanelWidth] else [0];

{
  /**
   * Returns a row with key metrics for service
   */
  headlineMetricsRow(
    serviceType,
    startRow,
    rowTitle='🌡️ Aggregated Service Level Indicators (𝙎𝙇𝙄𝙨)',
    selectorHash={},
    stableIdPrefix='',
    showApdex=true,
    apdexDescription=null,
    showErrorRatio=true,
    showOpsRate=true,
    showSaturationCell=true,
    compact=false,
    rowHeight=7,
    showDashboardListPanel=false,
    aggregationSet=aggregationSets.serviceSLIs,
    staticTitlePrefix=null,
    legendFormatPrefix=null,
    includeLastWeek=true,
    fixedThreshold=null,
    expectMultipleSeries=false,
  )::
    local typeHash = if serviceType == null then {} else { type: serviceType };
    local selectorHashWithExtras = selectorHash + typeHash;
    local formatConfig = { serviceType: serviceType, stableIdPrefix: stableIdPrefix };
    local titlePrefix = if staticTitlePrefix == null then '%(serviceType)s Service' % formatConfig else staticTitlePrefix;

    local metricsCatalogServiceInfo = metricsCatalog.getServiceOptional(serviceType);
    local shardLabels =
      if metricsCatalogServiceInfo != null && metricsCatalogServiceInfo.isShardLevelMonitored() then
        { shard: { re: '$shard' } }
      else
        {};
    local selectorHashWithShard = selectorHashWithExtras + shardLabels;

    local columns =
      singleMetricRow.row(
        serviceType=serviceType,
        sli=null,  // No SLI for headline metrics
        aggregationSet=aggregationSet,
        selectorHash=selectorHashWithExtras,
        titlePrefix=titlePrefix,
        stableIdPrefix='%(stableIdPrefix)sservice-%(serviceType)s' % formatConfig,
        legendFormatPrefix=if legendFormatPrefix == null then serviceType else legendFormatPrefix,
        showApdex=showApdex,
        apdexDescription=null,
        showErrorRatio=showErrorRatio,
        showOpsRate=showOpsRate,
        includePredictions=true,
        compact=compact,
        includeLastWeek=includeLastWeek,
        fixedThreshold=fixedThreshold,
        expectMultipleSeries=expectMultipleSeries,
      )
      +
      (
        if showSaturationCell then
          [[
            panels.utilizationRate(
              serviceType,
              selectorHash=selectorHashWithShard,
              compact=compact,
              stableId='%(stableIdPrefix)sservice-utilization' % formatConfig,
              linewidth=1,
            ),
          ]]
        else
          []
      )
      +
      (
        if showDashboardListPanel then
          [[
            managedDashboardsForService(serviceType),
          ]]
        else
          []
      );

    local columnWidths = getColumnWidths(
      showApdex=showApdex,
      showErrorRatio=showErrorRatio,
      showOpsRate=showOpsRate,
      showSaturationCell=showSaturationCell,
      showDashboardListPanel=showDashboardListPanel
    );

    (
      if rowTitle != null then
        layout.grid([
          row.new(title=rowTitle, collapse=false),
        ], cols=1, rowHeight=1, startRow=startRow)
      else
        []
    )
    +
    layout.splitColumnGrid(columns, [rowHeight - 1, 1], startRow=startRow + 1, columnWidths=columnWidths),
}
