local resolveRateQuery = (import './lib/resolve-rate-query.libsonnet').resolveRateQuery;
local generateApdexAttributionQuery = (import './lib/counter-apdex-attribution-query.libsonnet').attributionQuery;
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local strings = import 'utils/strings.libsonnet';
local metric = import '../metric.libsonnet';
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';
local metricLabelsSelectorsMixin = (import '../metrics-mixin.libsonnet').metricLabelsSelectorsMixin;

local transformErrorRateToSuccessRate(errorRateMetric, operationRateMetric, selector, rangeInterval, aggregationLabels, recordingRuleRegistry, offset) =
  |||
    %(operationRate)s - (
      %(errorRate)s or
      0 * %(indentedOperationRate)s
    )
  ||| % {
    operationRate: strings.chomp(resolveRateQuery(
      operationRateMetric,
      selector,
      rangeInterval,
      recordingRuleRegistry,
      aggregationFunction='sum',
      aggregationLabels=aggregationLabels,
      offset=offset,
    )),
    indentedOperationRate: strings.indent(strings.chomp(resolveRateQuery(
      operationRateMetric,
      selector,
      rangeInterval,
      recordingRuleRegistry,
      aggregationFunction='sum',
      aggregationLabels=aggregationLabels,
      offset=offset,

    )), 2),
    errorRate: strings.indent(strings.chomp(resolveRateQuery(
      errorRateMetric,
      selector,
      rangeInterval,
      recordingRuleRegistry,
      aggregationFunction='sum',
      aggregationLabels=aggregationLabels,
      offset=offset,
    )), 2),
  };


{
  // errorCounterApdex constructs an apdex score (ie, successes/total) from an error score (ie, errors/total).
  // This can be useful for latency metrics that count latencies that exceed threshold, instead of the more
  // common form of latencies that are within threshold.
  errorCounterApdex(errorRateMetric, operationRateMetric, selector, useRecordingRuleRegistry=true):: metric.new({
    errorRateMetric: errorRateMetric,
    operationRateMetric: operationRateMetric,
    selector: selector,
    useRecordingRuleRegistry:: useRecordingRuleRegistry,
    recordingRuleRegistry::
      if self.useRecordingRuleRegistry
      then self.config.recordingRuleRegistry
      else recordingRuleRegistry.nullRegistry,

    apdexSuccessRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      transformErrorRateToSuccessRate(
        self.errorRateMetric,
        self.operationRateMetric,
        selectors.without(selectors.merge(self.selector, selector), withoutLabels),
        rangeInterval,
        aggregationLabels,
        self.recordingRuleRegistry,
        offset,
      ),
    apdexWeightQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      resolveRateQuery(
        self.operationRateMetric,
        selectors.without(selectors.merge(self.selector, selector), withoutLabels),
        rangeInterval,
        self.recordingRuleRegistry,
        aggregationLabels=aggregationLabels,
        aggregationFunction='sum',
        offset=offset
      ),
    apdexNumerator(selector, rangeInterval, withoutLabels=[], offset=null)::
      transformErrorRateToSuccessRate(
        self.errorRateMetric,
        self.operationRateMetric,
        selectors.without(selectors.merge(self.selector, selector), withoutLabels),
        rangeInterval,
        [],
        self.recordingRuleRegistry,
        offset,
      ),

    apdexDenominator(selector, rangeInterval, withoutLabels=[], offset=null)::
      resolveRateQuery(
        self.operationRateMetric,
        selectors.without(selectors.merge(self.selector, selector), withoutLabels),
        rangeInterval,
        self.recordingRuleRegistry,
        offset
      ),

    apdexAttribution(aggregationLabel, selector, rangeInterval, withoutLabels=[])::
      generateApdexAttributionQuery(self, aggregationLabel, selector, rangeInterval, withoutLabels),

  } + metricLabelsSelectorsMixin(selector, [errorRateMetric, operationRateMetric])),
}
