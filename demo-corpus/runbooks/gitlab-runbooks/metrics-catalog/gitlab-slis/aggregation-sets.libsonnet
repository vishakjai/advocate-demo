local gitlabMetricsConfig = import 'gitlab-metrics-config.libsonnet';
local sliDefinition = import 'gitlab-slis/sli-definition.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local defaultRecordingRuleRegistry = gitlabMetricsConfig.recordingRuleRegistry;

local defaultLabels = ['environment', 'tier', 'type', 'stage'];
local globalLabels = ['env'];
local supportedBurnRates = ['5m', '1h'];

local resolvedRecording(metric, labels, burnRate, recordingRuleRegistry) =
  assert recordingRuleRegistry.resolveRecordingRuleFor(
    metricName=metric, aggregationLabels=labels, rangeInterval=burnRate
  ) != null : 'No previous recording found for %s and burn rate %s' % [metric, burnRate];
  recordingRuleRegistry.recordingRuleNameFor(metric, burnRate);

local recordedBurnRatesForSLI(sli, recordingRuleRegistry) =
  std.foldl(
    function(memo, burnRate)
      local apdex =
        if sli.hasApdex() then
          {
            apdexSuccessRate: resolvedRecording(sli.apdexSuccessCounterName, sli.significantLabels, burnRate, recordingRuleRegistry),
            apdexWeight: resolvedRecording(sli.apdexTotalCounterName, sli.significantLabels, burnRate, recordingRuleRegistry),
          }
        else {};

      local errorRate =
        if sli.hasErrorRate() then
          {
            errorRate: resolvedRecording(sli.errorCounterName, sli.significantLabels, burnRate, recordingRuleRegistry),
            opsRate: resolvedRecording(sli.errorTotalCounterName, sli.significantLabels, burnRate, recordingRuleRegistry),
          }
        else {};

      memo { [burnRate]: apdex + errorRate },
    supportedBurnRates,
    {}
  );

local aggregationFormats(sli) =
  local format = { sliName: sli.name, burnRate: '%s' };

  local apdex = if sli.hasApdex() then
    {
      apdexSuccessRate: 'application_sli_aggregation:%(sliName)s:apdex:success:rate_%(burnRate)s' % format,
      apdexWeight: 'application_sli_aggregation:%(sliName)s:apdex:weight:score_%(burnRate)s' % format,
    }
  else
    {};

  apdex + if sli.hasErrorRate() then
    {
      opsRate: 'application_sli_aggregation:%(sliName)s:ops:rate_%(burnRate)s' % format,
      errorRate: 'application_sli_aggregation:%(sliName)s:error:rate_%(burnRate)s' % format,
    }
  else
    {};

local sourceAggregationSet(sli, recordingRuleRegistry) =
  aggregationSet.AggregationSet(
    {
      id: 'source_application_sli_%s' % sli.name,
      name: 'Application Defined SLI Source metrics: %s' % sli.name,
      labels: defaultLabels + sli.significantLabels,
      intermediateSource: true,
      selector: { monitor: { ne: 'global' } },
      supportedBurnRates: supportedBurnRates,
    }
    +
    if sli.inRecordingRuleRegistry(registry=recordingRuleRegistry) then
      { burnRates: recordedBurnRatesForSLI(sli, recordingRuleRegistry) }
    else
      { metricFormats: aggregationFormats(sli) }
  );

local targetAggregationSet(sli, extraStaticLabels) =
  aggregationSet.AggregationSet({
    id: 'global_application_sli_%s' % sli.name,
    name: 'Application Defined SLI Global metrics: %s' % sli.name,
    labels:
      local allLabels = globalLabels + defaultLabels + sli.significantLabels;
      std.filter(function(aggregationLabel) !std.member(std.objectFields(sli.recordingRuleStaticLabels), aggregationLabel), allLabels),
    intermediateSource: false,
    generateSLODashboards: false,
    selector: { monitor: 'global' },
    supportedBurnRates: ['5m', '1h'],
    metricFormats: aggregationFormats(sli),
    recordingRuleStaticLabels: sli.recordingRuleStaticLabels + extraStaticLabels,
  });

{
  sourceAggregationSet(sli, recordingRuleRegistry=sli.config.recordingRuleRegistry):: sourceAggregationSet(sli, recordingRuleRegistry),
  targetAggregationSet(sli, extraStaticLabels={}):: targetAggregationSet(sli, extraStaticLabels),
}
