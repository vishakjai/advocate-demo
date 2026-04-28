local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local template = grafana.template;
local multiburnFactors = import 'mwmbr/multiburn_factors.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local statusDescription = import 'key-metric-panels/status_description.libsonnet';
local aggregationSets = (import 'mimir-aggregation-sets.libsonnet');
local wilsonScore = import 'wilson-score/wilson-score.libsonnet';
local durationParser = import 'utils/duration-parser.libsonnet';

local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';

local apdexSLOMetric = 'slo:min:events:gitlab_service_apdex:ratio';
local errorSLOMetric = 'slo:max:events:gitlab_service_errors:ratio';

local sliSeriesName(sliType, duration) =
  if sliType == 'apdex' then
    '%s apdex burn rate' % duration
  else
    '%s error burn rate' % duration;

local confidenceSeriesName(sliType, duration) =
  if sliType == 'apdex' then
    'apdex confidence upper boundary %s' % duration
  else
    'error rate confidence lower boundary %s' % duration;

local sliOverride(name, lineWidth, color, fillBelowTo) =
  local standardOptions = g.panel.timeSeries.standardOptions;
  local override = standardOptions.override;
  local custom = g.panel.timeSeries.fieldConfig.defaults.custom;

  override.byName.new(name)
  + override.byName.withPropertiesFromOptions(
    standardOptions.color.withMode('shades') +
    standardOptions.color.withFixedColor(color) +
    custom.withLineWidth(lineWidth) +
    (
      if fillBelowTo != null then
        custom.withFillBelowTo(fillBelowTo)
      else {}
    )
  );

local sloOverride(name, color) =
  local standardOptions = g.panel.timeSeries.standardOptions;
  local override = standardOptions.override;
  local custom = g.panel.timeSeries.fieldConfig.defaults.custom;

  override.byName.new(name)
  + override.byName.withPropertiesFromOptions(
    standardOptions.color.withMode('shades') +
    standardOptions.color.withFixedColor(color) +
    custom.withLineWidth(2) +
    custom.lineStyle.withFill('dash') +
    custom.lineStyle.withDash([10, 10])
  );


// Produces output to generate a confidence interval graph value
local confidenceIntervalGraphs(isLower, scoreMetric, totalMetric, duration, selectorHash) =
  local wilsonScoreFunc = if isLower then wilsonScore.lower else wilsonScore.upper;

  if scoreMetric != null && totalMetric != null then
    [{
      legendFormat: confidenceSeriesName(if isLower then 'error' else 'apdex', duration),
      query: wilsonScoreFunc(
        scoreRate='%s{%s}' % [scoreMetric, selectors.serializeHash(selectorHash)],
        totalRate='%s{%s}' % [totalMetric, selectors.serializeHash(selectorHash)],
        windowInSeconds=durationParser.toSeconds(duration),
        confidence='$confidence',
        confidenceIsZScore=true,
      ),
    }]
  else [];

local errorBurnRatePair(aggregationSet, shortDuration, longDuration, selectorHash) =
  local sliType = 'error';

  local formatConfig = {
    shortMetric: aggregationSet.getErrorRatioMetricForBurnRate(shortDuration, required=true),
    shortDuration: shortDuration,
    longMetric: aggregationSet.getErrorRatioMetricForBurnRate(longDuration, required=true),
    longDuration: longDuration,
    longBurnFactor: multiburnFactors.errorBudgetFactorFor(longDuration),
    selector: selectors.serializeHash(selectorHash + aggregationSet.selector),
    thresholdSLOMetricName: errorSLOMetric,
  };

  local longQuery =
    |||
      %(longMetric)s{%(selector)s}
    ||| % formatConfig;

  local shortQuery =
    |||
      %(shortMetric)s{%(selector)s}
    ||| % formatConfig;

  [
    {
      legendFormat: sliSeriesName(sliType, longDuration),
      query: longQuery,
    },
    {
      legendFormat: sliSeriesName(sliType, shortDuration),
      query: shortQuery,
    },
    {
      legendFormat: '%(longDuration)s error burn threshold' % formatConfig,
      query: '(%(longBurnFactor)g * avg(%(thresholdSLOMetricName)s{monitor="global", type="$type"})) unless (vector($proposed_slo) > 0)' % formatConfig,
    },
    {
      legendFormat: 'Proposed SLO @ %(longDuration)s burn' % formatConfig,
      query: '%(longBurnFactor)g * (1 - $proposed_slo)' % formatConfig,
    },
  ] +
  confidenceIntervalGraphs(true, aggregationSet.getErrorRateMetricForBurnRate(shortDuration), aggregationSet.getOpsRateMetricForBurnRate(shortDuration), shortDuration, aggregationSet.selector + selectorHash) +
  confidenceIntervalGraphs(true, aggregationSet.getErrorRateMetricForBurnRate(longDuration), aggregationSet.getOpsRateMetricForBurnRate(longDuration), longDuration, aggregationSet.selector + selectorHash);

local apdexBurnRatePair(aggregationSet, shortDuration, longDuration, selectorHash) =
  local sliType = 'apdex';

  local formatConfig = {
    shortMetric: aggregationSet.getApdexRatioMetricForBurnRate(shortDuration, required=true),
    shortDuration: shortDuration,
    longMetric: aggregationSet.getApdexRatioMetricForBurnRate(longDuration, required=true),
    longDuration: longDuration,
    longBurnFactor: multiburnFactors.errorBudgetFactorFor(longDuration),
    selector: selectors.serializeHash(selectorHash + aggregationSet.selector),
    thresholdSLOMetricName: apdexSLOMetric,
  };

  local longQuery =
    |||
      %(longMetric)s{%(selector)s}
    ||| % formatConfig;

  local shortQuery =
    |||
      %(shortMetric)s{%(selector)s}
    ||| % formatConfig;

  [
    {
      legendFormat: sliSeriesName(sliType, longDuration),
      query: longQuery,
    },
    {
      legendFormat: sliSeriesName(sliType, shortDuration),
      query: shortQuery,
    },
    {
      legendFormat: '%(longDuration)s apdex burn threshold' % formatConfig,
      query: '(1 - (%(longBurnFactor)g * (1 - avg(%(thresholdSLOMetricName)s{monitor="global", type="$type"})))) unless (vector($proposed_slo) > 0) ' % formatConfig,
    },
    {
      legendFormat: 'Proposed SLO @ %(longDuration)s burn' % formatConfig,
      query: '1 - (%(longBurnFactor)g * (1 - $proposed_slo))' % formatConfig,
    },
  ] +
  confidenceIntervalGraphs(false, aggregationSet.getApdexSuccessRateMetricForBurnRate(shortDuration), aggregationSet.getApdexWeightMetricForBurnRate(shortDuration), shortDuration, aggregationSet.selector + selectorHash) +
  confidenceIntervalGraphs(false, aggregationSet.getApdexSuccessRateMetricForBurnRate(longDuration), aggregationSet.getApdexWeightMetricForBurnRate(longDuration), longDuration, aggregationSet.selector + selectorHash);

local burnRatePanel(
  title,
  combinations,
  sliType,
  stableId,
      ) =
  local sloTypeDescription = if sliType == 'apdex' then 'apdex burn threshold' else 'error burn threshold';

  local basePanel =
    g.panel.timeSeries.new(title)
    + g.panel.timeSeries.queryOptions.withMaxDataPoints(1024 * 8)
    + g.panel.timeSeries.queryOptions.withInterval('15s')
    + g.panel.timeSeries.queryOptions.withTargetsMixin([
      g.query.prometheus.new(
        '$PROMETHEUS_DS',
        combinations[0].query,
      )
      + g.query.prometheus.withLegendFormat(combinations[0].legendFormat),
    ])
    + g.panel.timeSeries.standardOptions.withUnit('percentunit');

  std.foldl(
    function(memo, combo)
      memo
      + g.panel.timeSeries.queryOptions.withTargetsMixin([
        g.query.prometheus.new(
          '$PROMETHEUS_DS',
          combo.query
        )
        + g.query.prometheus.withLegendFormat(combo.legendFormat),
      ]),
    combinations[1:],
    basePanel
  )
  + g.panel.timeSeries.standardOptions.withOverridesMixin([
    sliOverride(
      name=sliSeriesName(sliType, '6h'),
      lineWidth=3,
      color='dark-purple',
      fillBelowTo=if sliType == 'error' then confidenceSeriesName(sliType, '6h') else null,
    ),
    sliOverride(
      name=confidenceSeriesName(sliType, '6h'),
      lineWidth=0,
      color='semi-dark-purple',
      fillBelowTo=if sliType == 'apdex' then sliSeriesName(sliType, '6h') else null,
    ),
    sliOverride(
      name=sliSeriesName(sliType, '30m'),
      lineWidth=2,
      color='light-purple',
      fillBelowTo=if sliType == 'error' then confidenceSeriesName(sliType, '30m') else null,
    ),
    sliOverride(
      name=confidenceSeriesName(sliType, '30m'),
      lineWidth=0,
      color='super-light-purple',
      fillBelowTo=if sliType == 'apdex' then sliSeriesName(sliType, '30m') else null,
    ),
    sliOverride(
      name=sliSeriesName(sliType, '1h'),
      lineWidth=3,
      color='dark-yellow',
      fillBelowTo=if sliType == 'error' then confidenceSeriesName(sliType, '1h') else null,
    ),
    sliOverride(
      name=confidenceSeriesName(sliType, '1h'),
      lineWidth=0,
      color='semi-dark-yellow',
      fillBelowTo=if sliType == 'apdex' then sliSeriesName(sliType, '1h') else null,
    ),
    sliOverride(
      name=sliSeriesName(sliType, '5m'),
      lineWidth=2,
      color='light-yellow',
      fillBelowTo=if sliType == 'error' then confidenceSeriesName(sliType, '5m') else null,
    ),
    sliOverride(
      name=confidenceSeriesName(sliType, '5m'),
      lineWidth=0,
      color='super-light-yellow',
      fillBelowTo=if sliType == 'apdex' then sliSeriesName(sliType, '5m') else null,
    ),
    sloOverride(
      name='6h %s' % sloTypeDescription,
      color='semi-dark-red'
    ),
    sloOverride(
      name='1h %s' % sloTypeDescription,
      color='super-light-red'
    ),
  ]);

local burnRatePanelWithHelp(
  title,
  combinations,
  sliType,
  content,
  stableId=null,
      ) =
  [
    burnRatePanel(title, combinations, sliType, stableId),
    grafana.text.new(
      title='Help',
      mode='markdown',
      content=content
    ),
  ];

local ignoredTemplateLabels = std.set(['env', 'tier']);

local generateTemplatesAndSelectorHash(sliType, aggregationSet, dashboard) =
  local metric = if sliType == 'error' then
    aggregationSet.getErrorRatioMetricForBurnRate('1h')
  else
    aggregationSet.getApdexRatioMetricForBurnRate('1h');

  std.foldl(
    function(memo, label)
      if std.member(ignoredTemplateLabels, label) then
        memo
      else
        local dashboard = memo.dashboard;
        local selectorHash = memo.selectorHash;

        local formatConfig = {
          metric: metric,
          label: label,
          selector: selectors.serializeHash(selectorHash),
        };

        local t = template.new(
          label,
          '$PROMETHEUS_DS',
          'label_values(%(metric)s{%(selector)s}, %(label)s)' % formatConfig,
          refresh='time',
          sort=1,
        );
        { dashboard: dashboard.addTemplate(t), selectorHash: selectorHash { [label]: '$' + label } },
    aggregationSet.labels,
    { dashboard: dashboard, selectorHash: aggregationSet.selector }
  );

local multiburnRateAlertsDashboard(
  sliType,
  aggregationSet,
      ) =

  local title =
    if sliType == 'apdex' then
      aggregationSet.name + ' Apdex SLO Analysis'
    else
      aggregationSet.name + ' Error SLO Analysis';

  local dashboardInitial =
    basic.dashboard(
      title,
      tags=['alert-target', 'general'],
    );

  local dashboardAndSelector =
    generateTemplatesAndSelectorHash(sliType, aggregationSet, dashboardInitial);

  local dashboardWithTemplates = dashboardAndSelector.dashboard.addTemplate(
    template.custom(
      'proposed_slo',
      'NaN,0.9,0.95,0.98,0.99,0.995,0.999,0.9995,0.9999',
      'NaN',
    )
  ).addTemplate(
    template.custom(
      'confidence',
      // For custom templates Grafana uses a
      // `key : value,key : value` format.
      // Construct this from the confidence intervals
      std.join(
        ',',
        std.map(
          function(confidence) '%s : %s' % [confidence, wilsonScore.confidenceLookup[confidence]],
          std.objectFields(wilsonScore.confidenceLookup)
        )
      ),
      '98%',
    )
  );

  local selectorHash = dashboardAndSelector.selectorHash;

  local sloMetricName = if sliType == 'apdex' then
    apdexSLOMetric
  else
    errorSLOMetric;
  local slaQuery =
    'avg(%s{monitor="global",type="$type"}) by (type)' % [sloMetricName];

  local pairFunction = if sliType == 'apdex' then apdexBurnRatePair else errorBurnRatePair;

  local oneHourBurnRateCombinations = pairFunction(
    aggregationSet=aggregationSet,
    shortDuration='5m',
    longDuration='1h',
    selectorHash=selectorHash
  );

  local sixHourBurnRateCombinations = pairFunction(
    aggregationSet=aggregationSet,
    shortDuration='30m',
    longDuration='6h',
    selectorHash=selectorHash
  );

  local statusDescriptionPanel = statusDescription.apdexStatusDescriptionPanel('SLO Analysis', selectorHash, aggregationSet=aggregationSet, sli=null);

  dashboardWithTemplates.addPanels(
    layout.columnGrid([
      [
        statusDescriptionPanel,
        basic.slaStats(
          title='',
          description='Availability',
          query=slaQuery,
          legendFormat='{{ type }} service monitoring SLO',
        ),
        grafana.text.new(
          title='Help',
          mode='markdown',
          content=|||
            The SLO for this service will determine the thresholds (indicated by the dotted lines)
            in the following graphs. Over time, we expect these SLOs to become stricter (more nines) by
            improving the reliability of our service.

            **For more details of this technique, be sure to the Alerting on SLOs chapter of the
            [Google SRE Workbook](https://landing.google.com/sre/workbook/chapters/alerting-on-slos/)**
          |||
        ),
      ],
    ], rowHeight=6, columnWidths=[6, 6, 12]) +
    layout.columnGrid([
      burnRatePanelWithHelp(
        title='Multi-window, multi-burn-rates',
        combinations=oneHourBurnRateCombinations + sixHourBurnRateCombinations,
        sliType=sliType,
        content=|||
          # Multi-window, multi-burn-rates

          The alert will fire when both of the green solid series cross the green dotted threshold, or
          both of the blue solid series cross the blue dotted threshold.
        |||,
        stableId='multiwindow-multiburnrate',
      ),
      burnRatePanelWithHelp(
        title='Single window, 1h/5m burn-rates',
        combinations=oneHourBurnRateCombinations,
        sliType=sliType,
        content=|||
          # Single window, 1h/5m burn-rates

          Removing the 6h/30m burn-rates, this shows the same data over the 1h/5m burn-rates.

          The alert will fire when the solid lines cross the dotted threshold.
        |||,
      ),
      burnRatePanelWithHelp(
        title='Single window, 6h/30m burn-rates',
        combinations=sixHourBurnRateCombinations,
        sliType=sliType,
        content=|||
          # Single window, 6h/30m burn-rates

          Removing the 1h/5m burn-rates, this shows the same data over the 6h/30m burn-rates.

          The alert will fire when the solid lines cross the dotted threshold.
        |||
      ),
      burnRatePanelWithHelp(
        title='Single window, 1h/5m burn-rates, no thresholds',
        combinations=oneHourBurnRateCombinations[:2] + oneHourBurnRateCombinations[4:],
        sliType=sliType,
        content=|||
          # Single window, 1h/5m burn-rates, no thresholds

          Since the threshold can be relatively high, removing it can help visualise the current values better.
        |||
      ),
      burnRatePanelWithHelp(
        title='Single window, 6h/30m burn-rates, no thresholds',
        combinations=sixHourBurnRateCombinations[:2] + sixHourBurnRateCombinations[4:],
        sliType=sliType,
        content=|||
          # Single window, 6h/30m burn-rates, no thresholds

          Since the threshold can be relatively high, removing it can help visualise the current values better.
        |||
      ),
    ], columnWidths=[18, 6], rowHeight=10, startRow=100)
  )
  .trailer()
  + {
    links+: platformLinks.triage,
  };

local aggregationSetsForSLOAnalysisDashboards =
  std.filter(
    function(aggregationSet)
      aggregationSet.generateSLODashboards,
    std.objectValues(aggregationSets)
  );

std.foldl(
  function(memo, aggregationSet)
    memo {
      [aggregationSet.id + '_slo_apdex']: multiburnRateAlertsDashboard(
        sliType='apdex',
        aggregationSet=aggregationSet,
      ),
      [aggregationSet.id + '_slo_error']: multiburnRateAlertsDashboard(
        sliType='error',
        aggregationSet=aggregationSet,
      ),
    },
  aggregationSetsForSLOAnalysisDashboards,
  {}
)
