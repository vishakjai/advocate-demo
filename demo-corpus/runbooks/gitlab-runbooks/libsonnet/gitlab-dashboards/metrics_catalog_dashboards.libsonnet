local thresholds = import './thresholds.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local singleMetricRow = import 'key-metric-panels/single-metric-row.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local misc = import 'utils/misc.libsonnet';
local objects = import 'utils/objects.libsonnet';
local override = import 'grafana/time-series/override.libsonnet';

local row = grafana.row;

local ignoreZero(query) = '%s > 0' % [query];

local getLatencyPercentileForService(serviceType) =
  local service = if serviceType == null then {} else metricsCatalog.getService(serviceType);

  if std.objectHas(service, 'contractualThresholds') && std.objectHas(service.contractualThresholds, 'apdexRatio') then
    service.contractualThresholds.apdexRatio
  else
    0.95;

local getMarkdownDetailsForSLI(sli, sliSelectorHash) =
  local items = std.prune([
    (
      if sli.description != '' then
        |||
          ### Description

          %(description)s
        ||| % {
          description: sli.description,
        }
      else
        null
    ),
    (
      if sli.hasToolingLinks() then
        // We pass the selector hash to the tooling links they may
        // be used to customize the links
        local toolingOptions = { prometheusSelectorHash: sliSelectorHash };
        |||
          ### Observability Tools

          %(links)s
        ||| % {
          links: toolingLinks.generateMarkdown(sli.getToolingLinks(), toolingOptions),
        }
      else
        null
    ),
  ]);

  std.join('\n\n', items);

local sliOverviewMatrixRow(
  serviceType,
  sli,
  startRow,
  selectorHash,
  aggregationSet,
  legendFormatPrefix,
  expectMultipleSeries,
  shardAggregationSet=null,  // replaces aggregationSet if exists
      ) =
  local typeSelector = if serviceType == null then {} else { type: serviceType };
  local shardSelector = if shardAggregationSet != null && sli.shardLevelMonitoring then
    { shard: { re: '$shard' } }
  else
    {};
  local selectorHashWithExtras = selectorHash { component: sli.name } + typeSelector + shardSelector;

  local legendFormatPrefixWithShard = if shardAggregationSet != null && sli.shardLevelMonitoring then
    '%(sliName)s - %(shard)s shard' % { sliName: sli.name, shard: '{{ shard }}' }
  else
    sli.name;

  local formatConfig = {
    serviceType: serviceType,
    sliName: sli.name,
    legendFormatPrefix: if legendFormatPrefix != '' then legendFormatPrefix else legendFormatPrefixWithShard,
  };

  local columns =
    singleMetricRow.row(
      serviceType=serviceType,
      sli=sli,
      aggregationSet=if shardAggregationSet != null && sli.shardLevelMonitoring then shardAggregationSet else aggregationSet,
      selectorHash=selectorHashWithExtras,
      titlePrefix=if !sli.shardLevelMonitoring then '%(sliName)s SLI' % formatConfig else '%(sliName)s SLI (By Shard)' % formatConfig,
      stableIdPrefix='sli-%(sliName)s' % formatConfig,
      legendFormatPrefix='%(legendFormatPrefix)s' % formatConfig,
      expectMultipleSeries=expectMultipleSeries,
      showApdex=sli.hasApdex(),
      showErrorRatio=sli.hasErrorRate(),
      showOpsRate=true,
      includePredictions=false,
      shardLevelSli=sli.shardLevelMonitoring,
    )
    +
    (
      local markdown = getMarkdownDetailsForSLI(sli, selectorHash);
      if markdown != '' then
        [[
          grafana.text.new(
            title='Details',
            mode='markdown',
            content=markdown,
          ),
        ]]
      else
        []
    );

  layout.splitColumnGrid(columns, [7, 1], startRow=startRow);

local sliDetailLatencyPanel(
  title=null,
  sli=null,
  serviceType=null,
  selector=null,
  aggregationLabels='',
  logBase=10,
  legendFormat='%(percentile_humanized)s %(sliName)s',
  min=0.01,
  intervalFactor=1,
  withoutLabels=[],
      ) =
  local percentile = getLatencyPercentileForService(serviceType);
  local formatConfig = { percentile_humanized: 'p%g' % [percentile * 100], sliName: sli.name };

  panel.latencyTimeSeries(
    title=(if title == null then 'Estimated %(percentile_humanized)s latency for %(sliName)s' + sli.name else title) % formatConfig,
    query=ignoreZero(sli.apdex.percentileLatencyQuery(
      percentile=percentile,
      aggregationLabels=aggregationLabels,
      selector=selector,
      rangeInterval='$__interval',
      withoutLabels=withoutLabels,
    )),
    format=sli.apdex.unit,
    legendFormat=legendFormat % formatConfig,
    min=min,
    intervalFactor=intervalFactor,
  ) + {
    thresholds: std.prune([
      if sli.apdex.toleratedThreshold != null then thresholds.errorLevel('gt', sli.apdex.toleratedThreshold),
      thresholds.warningLevel('gt', sli.apdex.satisfiedThreshold),
    ]),
  };

local sliDetailOpsRatePanel(
  title=null,
  serviceType=null,
  sli=null,
  selector=null,
  aggregationLabels='',
  legendFormat='%(sliName)s operations',
  intervalFactor=1,
  withoutLabels=[],
      ) =
  panel.timeSeries(
    title=if title == null then 'RPS for ' + sli.name else title,
    query=ignoreZero(sli.requestRate.aggregatedRateQuery(
      aggregationLabels=aggregationLabels,
      selector=selector,
      rangeInterval='$__interval',
      withoutLabels=withoutLabels,
    )),
    legendFormat=legendFormat % { sliName: sli.name },
    intervalFactor=intervalFactor,
    yAxisLabel='Requests per Second'
  );

local sliDetailErrorRatePanel(
  title=null,
  sli=null,
  selector=null,
  aggregationLabels='',
  legendFormat='%(sliName)s errors',
  intervalFactor=1,
  withoutLabels=[],
      ) =
  panel.timeSeries(
    title=if title == null then 'Errors for ' + sli.name else title,
    query=ignoreZero(sli.errorRate.aggregatedRateQuery(
      aggregationLabels=aggregationLabels,
      selector=selector,
      rangeInterval='$__interval',
      withoutLabels=withoutLabels,
    )),
    legendFormat=legendFormat % { sliName: sli.name },
    intervalFactor=intervalFactor,
    yAxisLabel='Errors',
  );
{
  // Generates a grid/matrix of SLI data for the given service/stage
  sliMatrixForService(
    title,
    serviceType,
    aggregationSet,
    startRow,
    selectorHash,
    legendFormatPrefix='',
    expectMultipleSeries=false,
    shardAggregationSet=null,
  )::
    local service = metricsCatalog.getService(serviceType);
    [
      row.new(title=title, collapse=false) { gridPos: { x: 0, y: startRow, w: 24, h: 1 } },
    ] +
    std.prune(
      std.flattenArrays(
        std.mapWithIndex(
          function(i, sliName)
            sliOverviewMatrixRow(
              serviceType=serviceType,
              aggregationSet=aggregationSet,
              sli=service.serviceLevelIndicators[sliName],
              selectorHash=selectorHash { type: serviceType },
              startRow=startRow + 1 + i * 10,
              legendFormatPrefix=legendFormatPrefix,
              expectMultipleSeries=expectMultipleSeries,
              shardAggregationSet=shardAggregationSet,
            ), std.objectFields(service.serviceLevelIndicators)
        )
      )
    ),

  sliMatrixAcrossServices(
    title,
    serviceTypes,
    aggregationSet,
    startRow,
    selectorHash,
    legendFormatPrefix='',
    expectMultipleSeries=false,
    sliFilter=function(x) x,
  )::

    local allSLIsForServices = std.flatMap(
      function(serviceType) std.objectValues(metricsCatalog.getService(serviceType).serviceLevelIndicators),
      serviceTypes
    );
    local filteredSLIs = std.filter(sliFilter, allSLIsForServices);
    local slis = std.foldl(
      function(memo, sli)
        memo { [sli.name]: sli },
      filteredSLIs,
      {}
    );

    layout.titleRowWithPanels(
      title=title,
      collapse=true,
      startRow=startRow,
      panels=layout.rows(
        std.prune(
          std.mapWithIndex(
            function(i, sliName)
              local sli = slis[sliName];

              if sliFilter(sli) then
                sliOverviewMatrixRow(
                  serviceType=null,
                  aggregationSet=aggregationSet,
                  sli=sli,
                  selectorHash=selectorHash,
                  startRow=startRow + 1 + i * 10,
                  legendFormatPrefix=legendFormatPrefix,
                  expectMultipleSeries=expectMultipleSeries,
                )
              else
                [],
            std.objectFields(slis)
          )
        )
      )
    ),

  sliDetailMatrix(
    serviceType,
    sliName,
    selectorHash,
    aggregationSets,
    minLatency=0.01,
  )::
    local service = metricsCatalog.getService(serviceType);
    local sli = service.serviceLevelIndicators[sliName];

    local staticLabelNames = if std.objectHas(sli, 'staticLabels') then std.objectFields(sli.staticLabels) else [];

    // Note that we always want to ignore `type` filters, since the metricsCatalog selectors will
    // already have correctly filtered labels to ensure the right values, and if we inject the type
    // we may lose metrics 'proxied' from nodes with other types
    local filteredSelectorHash = selectors.without(selectorHash, [
      'type',
    ] + staticLabelNames);

    row.new(title='🔬 SLI Detail: %(sliName)s' % { sliName: sliName }, collapse=true)
    .addPanels(
      std.flattenArrays(
        std.mapWithIndex(
          function(index, aggregationSet)
            local shardSelector = if sli.shardLevelMonitoring then
              { shard: { re: '$shard' } }
            else
              {};
            local combinedSelector = filteredSelectorHash + aggregationSet.selector + shardSelector;
            layout.singleRow(
              std.prune(
                [
                  if sli.hasHistogramApdex() then
                    sliDetailLatencyPanel(
                      title='Estimated %(percentile_humanized)s ' + sliName + ' Latency - ' + aggregationSet.title,
                      serviceType=serviceType,
                      sli=sli,
                      selector=combinedSelector,
                      legendFormat='%(percentile_humanized)s ' + aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      min=minLatency,
                    )
                  else
                    null,

                  if misc.isPresent(aggregationSet.aggregationLabels) && sli.hasApdex() && std.objectHasAll(sli.apdex, 'apdexAttribution') then
                    panel.percentageTimeSeries(
                      title='Apdex attribution for ' + sliName + ' Latency - ' + aggregationSet.title,
                      description='Attributes apdex downscoring',
                      query=sli.apdex.apdexAttribution(
                        aggregationLabel=aggregationSet.aggregationLabels,
                        selector=combinedSelector,
                        rangeInterval='$__interval',
                      ),
                      legendFormat=aggregationSet.legendFormat % { sliName: sliName },
                      intervalFactor=1,
                      linewidth=1,
                      fill=40,
                      stack=true,
                    )
                    .addSeriesOverride(override.negativeY)
                  else
                    null,

                  if sli.hasErrorRate() then
                    sliDetailErrorRatePanel(
                      title=sliName + ' Errors - ' + aggregationSet.title,
                      sli=sli,
                      legendFormat=aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      selector=combinedSelector
                    )
                  else
                    null,

                  if sli.hasAggregatableRequestRate() then
                    sliDetailOpsRatePanel(
                      title=sliName + ' RPS - ' + aggregationSet.title,
                      sli=sli,
                      selector=combinedSelector,
                      legendFormat=aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                    )
                  else
                    null,
                ]
              ),
              startRow=index * 10
            ),
          aggregationSets
        )
      )
    ),

  sliDetailMatrixAcrossServices(
    sli,
    selectorHash,
    aggregationSets,
    minLatency=0.01
  )::
    // Note that we always want to ignore `type` filters, since the metricsCatalog selectors will
    // already have correctly filtered labels to ensure the right values, and if we inject the type
    // we may lose metrics 'proxied' from nodes with other types
    local staticLabelNames = if std.objectHas(sli, 'staticLabels') then std.objectFields(sli.staticLabels) else [];
    local withoutLabels = ['type'] + staticLabelNames;
    local filteredSelectorHash = selectors.without(selectorHash, withoutLabels);

    row.new(title='🔬 SLI Detail: %(sliName)s' % { sliName: sli.name }, collapse=true)
    .addPanels(
      std.flattenArrays(
        std.mapWithIndex(
          function(index, aggregationSet)
            local combinedSelector = aggregationSet.selector + filteredSelectorHash;

            layout.singleRow(
              std.prune(
                [
                  if sli.hasHistogramApdex() then
                    sliDetailLatencyPanel(
                      title='Estimated %(percentile_humanized)s ' + sli.name + ' Latency - ' + aggregationSet.title,
                      sli=sli,
                      selector=combinedSelector,
                      legendFormat='%(percentile_humanized)s ' + aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      withoutLabels=withoutLabels,
                      min=minLatency,
                    )
                  else
                    null,

                  if misc.isPresent(aggregationSet.aggregationLabels) && sli.hasApdex() && std.objectHasAll(sli.apdex, 'apdexAttribution') then
                    panel.percentageTimeseries(
                      title='Apdex attribution for ' + sli.name + ' Latency - ' + aggregationSet.title,
                      description='Attributes apdex downscoring',
                      query=sli.apdex.apdexAttribution(
                        aggregationLabel=aggregationSet.aggregationLabels,
                        selector=combinedSelector,
                        rangeInterval='$__interval',
                        withoutLabels=withoutLabels,
                      ),
                      legendFormat=aggregationSet.legendFormat % { sliName: sli.name },
                      intervalFactor=1,
                      linewidth=1,
                      fill=4,
                      stack=true,
                    )
                    .addSeriesOverride(seriesOverrides.negativeY)
                  else
                    null,

                  if sli.hasErrorRate() then
                    sliDetailErrorRatePanel(
                      title=sli.name + ' Errors - ' + aggregationSet.title,
                      sli=sli,
                      legendFormat=aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      selector=combinedSelector,
                      withoutLabels=withoutLabels,
                    )
                  else
                    null,

                  if sli.hasAggregatableRequestRate() then
                    sliDetailOpsRatePanel(
                      title=sli.name + ' RPS - ' + aggregationSet.title,
                      sli=sli,
                      selector=combinedSelector,
                      legendFormat=aggregationSet.legendFormat,
                      aggregationLabels=aggregationSet.aggregationLabels,
                      withoutLabels=withoutLabels,
                    )
                  else
                    null,
                ]
              ),
              startRow=index * 10
            ),
          aggregationSets
        )
      )
    ),

  autoDetailRows(serviceType, selectorHash, startRow)::
    local s = self;
    local service = metricsCatalog.getService(serviceType);
    local serviceLevelIndicators = service.listServiceLevelIndicators();
    local serviceLevelIndicatorsFiltered = std.filter(function(c) c.supportsDetails(), serviceLevelIndicators);

    layout.grid(
      std.mapWithIndex(
        function(i, sli)
          local aggregationSets =
            [
              { title: 'Overall', aggregationLabels: '', selector: {}, legendFormat: 'overall' },
            ] +
            std.map(function(c) { title: 'per ' + c, aggregationLabels: c, selector: { [c]: { ne: '' } }, legendFormat: '{{' + c + '}}' }, sli.significantLabels);

          s.sliDetailMatrix(serviceType, sli.name, selectorHash, aggregationSets),
        serviceLevelIndicatorsFiltered
      )
      , cols=1, startRow=startRow
    ),

  autoDetailRowsAcrossServices(
    serviceTypes,
    selectorHash,
    startRow,
    sliFilter=function(x) x,
  )::
    local s = self;
    local slis = objects.fromPairs(
      std.filter(
        function(pair) pair[1].supportsDetails() && sliFilter(pair[1]),
        std.flattenArrays(
          std.map(
            function(serviceType) objects.toPairs(metricsCatalog.getService(serviceType).serviceLevelIndicators),
            serviceTypes
          ),
        ),
      ),
    );

    layout.grid(
      std.filterMap(
        function(i, sliName) std.length(slis[sliName].significantLabels) > 0,
        function(i, sliName)
          local sli = slis[sliName];

          local aggregationSets =
            [
              { title: 'Overall', aggregationLabels: '', selector: {}, legendFormat: 'overall' },
            ] +
            std.map(function(c) { title: 'per ' + c, aggregationLabels: c, selector: { [c]: { ne: '' } }, legendFormat: '{{' + c + '}}' }, sli.significantLabels);

          s.sliDetailMatrixAcrossServices(sli, selectorHash, aggregationSets),
        std.objectFields(slis)
      )
      , cols=1, startRow=startRow
    ),
}
