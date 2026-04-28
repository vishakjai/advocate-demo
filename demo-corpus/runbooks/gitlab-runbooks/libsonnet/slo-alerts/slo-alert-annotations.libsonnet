/**
 * This libsonnet will generate common annotations for SLO alerts
 */
local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';

// These are labels which will always get ignored when generating the selectors
// for the PromQL expression generated in the alert annotation
local ignoredSelectorLabels = std.set(labelTaxonomy.labelTaxonomy(
  labelTaxonomy.labels.sliComponent |
  labelTaxonomy.labels.service |
  labelTaxonomy.labels.tier |
  labelTaxonomy.labels.environmentThanos
));

// Labels that are excluded from the aggregation when generating PromQL expression
local ignoredAggregationLabels = std.set(labelTaxonomy.labelTaxonomy(
  labelTaxonomy.labels.sliComponent |
  labelTaxonomy.labels.service
));

local promQueryForSelector(serviceType, sli, aggregationSet, metricName) =
  local selector = std.foldl(
    function(memo, label)
      local value =
        if std.member(ignoredSelectorLabels, label) then null else '{{ $labels.' + label + ' }}';

      if value == null then
        memo
      else
        memo { [label]: { eq: value } },
    aggregationSet.labels,
    {},
  );

  local aggregationLabels = std.filter(function(l) !std.member(ignoredAggregationLabels, l), aggregationSet.labels);

  if !sli.supportsDetails() then
    null
  else
    // TODO: Use recordingRuleRegistry.unifiedRegistry after we have migrated to Mimir
    local config = { recordingRuleRegistry: recordingRuleRegistry.nullRegistry };
    if sli.hasHistogramApdex() && metricName == 'apdex' then
      local apdexMetric = sli.apdex { config+: config };
      apdexMetric.percentileLatencyQuery(
        percentile=0.95,
        aggregationLabels=aggregationLabels,
        selector=selector,
        rangeInterval='5m',
      )
    else if sli.hasErrorRate() && metricName == 'error' then
      local errorRateMetric = sli.errorRate { config+: config };
      errorRateMetric.aggregatedRateQuery(
        aggregationLabels=aggregationLabels,
        selector=selector,
        rangeInterval='5m',
      )
    else if metricName == 'ops' then
      local requestRateMetric = sli.requestRate { config+: config };
      requestRateMetric.aggregatedRateQuery(
        aggregationLabels=aggregationLabels,
        selector=selector,
        rangeInterval='5m',
      )
    else
      null;


// By convention, we know that the Grafana UID will
// be <service>-main/<service>-overview
local dashboardForService(serviceType) =
  '%(serviceType)s-main/%(serviceType)s-overview' % {
    serviceType: serviceType,
  };

// Generates some common annotations for each SLO alert
function(serviceType, sli, aggregationSet, metricName)
  local panelSuffix =
    if metricName == 'apdex' then 'apdex'
    else if metricName == 'error' then 'error-rate'
    else if metricName == 'ops' then 'ops-rate'
    else error 'unrecognised metric type: metricName="%s"' % [metricName];

  local panelStableId = 'sli-%s-%s' % [sli.name, panelSuffix];
  local grafanaVariables = if std.member(aggregationSet.labels, 'shard') then
    ['environment', 'stage', 'shard']
  else
    ['environment', 'stage'];

  {
    // TODO: improve on grafana dashboard links
    grafana_dashboard_id: dashboardForService(serviceType),
    grafana_panel_id: stableIds.hashStableId(panelStableId),
    grafana_variables: std.join(',', grafanaVariables),
    grafana_min_zoom_hours: '6',

    promql_template_1: promQueryForSelector(serviceType, sli, aggregationSet, metricName),
  }
