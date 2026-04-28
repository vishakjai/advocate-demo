local statusDescription = import './status_description.libsonnet';
local panels = import './time-series/panels.libsonnet';

local selectorToGrafanaURLParams(selectorHash) =
  local pairs = std.foldl(
    function(memo, key)
      if std.objectHas(selectorHash, key) then
        memo + ['var-' + key + '=' + selectorHash[key]]
      else
        memo,
    ['fqdn', 'component', 'type', 'stage'],
    [],
  );
  std.join('&', pairs);

// Returns a row in column format, specifically designed for consumption in
local row(
  serviceType,
  sli,  // The serviceLevelIndicator object for which this row is being create (CAN BE NULL for headline rows etc)
  aggregationSet,
  selectorHash,
  titlePrefix,
  stableIdPrefix,
  legendFormatPrefix,
  showApdex,
  apdexDescription=null,
  showErrorRatio,
  showOpsRate,
  includePredictions=false,
  expectMultipleSeries=false,
  compact=false,
  includeLastWeek=true,
  fixedThreshold=null,
  shardLevelSli=false,
      ) =
  local typeSelector = if serviceType == null then {} else { type: serviceType };
  local selectorHashWithExtras = selectorHash + typeSelector;
  local formatConfig = {
    titlePrefix: titlePrefix,
    legendFormatPrefix: legendFormatPrefix,
    stableIdPrefix: stableIdPrefix,
    aggregationId: aggregationSet.id,
    grafanaURLPairs: selectorToGrafanaURLParams(selectorHash),
  };

  (
    // SLI Component apdex
    if showApdex then
      [
        [
          panels.apdex(
            title='%(titlePrefix)s Apdex' % formatConfig,
            sli=sli,
            aggregationSet=aggregationSet,
            selectorHash=selectorHashWithExtras,
            stableId='%(stableIdPrefix)s-apdex' % formatConfig,
            legendFormat='%(legendFormatPrefix)s apdex' % formatConfig,
            description=apdexDescription,
            expectMultipleSeries=expectMultipleSeries,
            compact=compact,
            fixedThreshold=fixedThreshold,
            includeLastWeek=includeLastWeek,
            shardLevelSli=shardLevelSli,
          )
          .addDataLink({
            url: '/d/alerts-%(aggregationId)s_slo_apdex?${__url_time_range}&${__all_variables}&%(grafanaURLPairs)s' % formatConfig {},
            title: '%(titlePrefix)s Apdex SLO Analysis' % formatConfig,
            targetBlank: true,
          }),
        ]
        +
        (
          if expectMultipleSeries then
            []
          else
            [statusDescription.apdexStatusDescriptionPanel(
              titlePrefix,
              selectorHashWithExtras,
              sli=sli,
              aggregationSet=aggregationSet,
              fixedThreshold=fixedThreshold
            )]
        ),
      ]
    else
      []
  )
  +
  (
    // SLI Error rate
    if showErrorRatio then
      [
        [
          panels.errorRatio(
            '%(titlePrefix)s Error Ratio' % formatConfig,
            sli=sli,
            aggregationSet=aggregationSet,
            selectorHash=selectorHashWithExtras,
            stableId='%(stableIdPrefix)s-error-rate' % formatConfig,
            legendFormat='%(legendFormatPrefix)s error ratio' % formatConfig,
            expectMultipleSeries=expectMultipleSeries,
            compact=compact,
            fixedThreshold=fixedThreshold,
            includeLastWeek=includeLastWeek,
            shardLevelSli=shardLevelSli
          )
          .addDataLink({
            url: '/d/alerts-%(aggregationId)s_slo_error?${__url_time_range}&${__all_variables}&%(grafanaURLPairs)s' % formatConfig,
            title: '%(titlePrefix)s Error-Rate SLO Analysis' % formatConfig,
            targetBlank: true,
          }),
        ]
        +
        (
          if expectMultipleSeries then
            []
          else
            [statusDescription.errorRateStatusDescriptionPanel(
              titlePrefix,
              selectorHashWithExtras,
              sli=sli,
              aggregationSet=aggregationSet,
              fixedThreshold=fixedThreshold
            )]
        ),
      ]
    else
      []
  )
  +
  (
    // SLI request rate (mandatory, but not all are aggregatable)
    if showOpsRate then
      [[
        panels.operationRate(
          '%(titlePrefix)s RPS - Requests per Second' % formatConfig,
          aggregationSet=aggregationSet,
          selectorHash=selectorHashWithExtras,
          stableId='%(stableIdPrefix)s-ops-rate' % formatConfig,
          legendFormat='%(legendFormatPrefix)s RPS' % formatConfig,
          expectMultipleSeries=expectMultipleSeries,
          includePredictions=includePredictions,
          includeLastWeek=includeLastWeek,
          compact=compact,
        ),
      ]]
    else
      []
  );

{
  row:: row,
}
