local resolveRateQuery = (import './lib/resolve-rate-query.libsonnet').resolveRateQuery;
local aggregations = import 'promql/aggregations.libsonnet';
local generateApdexAttributionQuery = (import './lib/counter-apdex-attribution-query.libsonnet').attributionQuery;
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';

local selectors = import 'promql/selectors.libsonnet';
local strings = import 'utils/strings.libsonnet';
local metric = import '../metric.libsonnet';
local metricLabelsSelectorsMixin = (import '../metrics-mixin.libsonnet').metricLabelsSelectorsMixin;

local generateApdexRatio(successCounterApdex, aggregationLabels, additionalSelectors, rangeInterval, withoutLabels=[]) =
  |||
    %(successRateQuery)s
    /
    %(weightQuery)s
  ||| % {
    successRateQuery: successCounterApdex.successRateQuery(aggregationLabels, additionalSelectors, rangeInterval, withoutLabels=withoutLabels),
    weightQuery: successCounterApdex.apdexWeightQuery(aggregationLabels, additionalSelectors, rangeInterval, withoutLabels=withoutLabels),
  };

{
  successCounterApdex(successRateMetric, operationRateMetric, selector={}, useRecordingRuleRegistry=true):: metric.new({
    successRateMetric: successRateMetric,
    operationRateMetric: operationRateMetric,
    selector: selector,
    useRecordingRuleRegistry:: useRecordingRuleRegistry,
    recordingRuleRegistry::
      if self.useRecordingRuleRegistry
      then self.config.recordingRuleRegistry
      else recordingRuleRegistry.nullRegistry,

    apdexSuccessRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      resolveRateQuery(
        self.successRateMetric,
        selectors.without(selectors.merge(self.selector, selector), withoutLabels),
        rangeInterval,
        self.recordingRuleRegistry,
        offset,
        aggregationLabels=aggregationLabels,
        aggregationFunction='sum',
      ),
    apdexWeightQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      resolveRateQuery(
        self.operationRateMetric,
        selectors.without(selectors.merge(self.selector, selector), withoutLabels),
        rangeInterval,
        self.recordingRuleRegistry,
        offset,
        aggregationLabels=aggregationLabels,
        aggregationFunction='sum'
      ),
    apdexQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
      generateApdexRatio(self, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

    apdexNumerator(selector, rangeInterval, withoutLabels=[])::
      resolveRateQuery(
        self.successRateMetric,
        selectors.without(selectors.merge(self.selector, selector), withoutLabels),
        rangeInterval,
        self.recordingRuleRegistry,
      ),

    apdexDenominator(selector, rangeInterval, withoutLabels=[])::
      resolveRateQuery(
        self.operationRateMetric,
        selectors.without(selectors.merge(self.selector, selector), withoutLabels),
        rangeInterval,
        self.recordingRuleRegistry,
      ),

    apdexAttribution(aggregationLabel, selector, rangeInterval, withoutLabels=[])::
      generateApdexAttributionQuery(self, aggregationLabel, selectors.merge(self.selector, selector), rangeInterval, withoutLabels),

  } + metricLabelsSelectorsMixin(selector, [successRateMetric, operationRateMetric])),
}
