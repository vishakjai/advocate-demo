local metric = import '../metric.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local optionalOffset = import 'recording-rules/lib/optional-offset.libsonnet';
local strings = import 'utils/strings.libsonnet';
local metricLabelsSelectorsMixin = (import '../metrics-mixin.libsonnet').metricLabelsSelectorsMixin;

// A general apdex query is:
//
// 1. Some kind of satisfaction query (with a single threshold, a
//    double threshold, or even a combination of thresholds or-ed
//    together)
// 2. Divided by an optional denominator (when it's a double threshold
//    query; see
//    https://prometheus.io/docs/practices/histograms/#apdex-score)
// 3. Divided by some kind of weight score (either a single weight, or a
//    combination of weights or-ed together).
//
// The other functions here all use this to generate the final apdex
// query.

local generateApdexComponentRateQuery(histogramApdex, additionalSelectors, rangeInterval, leSelector={}, aggregationFunction=null, aggregationLabels=[], withoutLabels=[], offset=null) =
  local selector = selectors.merge(histogramApdex.selector, additionalSelectors);
  local selectorWithLe = selectors.merge(selector, leSelector);
  local selectorWithout = selectors.without(selectorWithLe, withoutLabels);

  local resolvedRecordingRule = histogramApdex.config.recordingRuleRegistry.resolveRecordingRuleFor(
    aggregationFunction=aggregationFunction,
    aggregationLabels=aggregationLabels,
    rangeVectorFunction=histogramApdex.rangeVectorFunction,
    metricName=histogramApdex.histogram,
    rangeInterval=rangeInterval,
    selector=selectorWithout,
  );

  if !histogramApdex.useRecordingRuleRegistry || resolvedRecordingRule == null then
    local query = '%(rangeVectorFunction)s(%(histogram)s{%(selector)s}[%(rangeInterval)s]%(optionalOffset)s)' % {
      histogram: histogramApdex.histogram,
      rangeVectorFunction: histogramApdex.rangeVectorFunction,
      selector: selectors.serializeHash(selectorWithout),
      rangeInterval: rangeInterval,
      optionalOffset: optionalOffset(offset),
    };

    if aggregationFunction == null then
      query
    else
      aggregations.aggregateOverQuery(aggregationFunction, aggregationLabels, query)
  else
    resolvedRecordingRule;

// Since we're using a regular expression, we need to escape the `.` otherwise
// it will match any character and could match a bigger le value
local escapeRegexpDecimal(value) =
  local str = if std.isNumber(value) then '%g' % [value] else value;
  std.strReplace(str, '.', '\\\\.');

// Prometheus 3.0 automatically normalizes buckets of histograms to floats.
// For example: `le="1"` will become `le="1.0"`
// jsonnet does not distinguish floats and integers, so we need to manually translate
// round numbers to floats.
// If the specified value was a string, just use that.
local prometheusFloatValue(value) =
  if std.isString(value) then value
  else if std.floor(value) == value then
    '%d.0' % [value]
  else
    '%g' % [value];

// Enables the histogramApdex to handle floats, integers or floats+integers
// Depends on metricsFormat
// 1) If metricsFormat isn't defined, it defaults to Prometheus, which will normalize the number to a float.
// 2) If metricsFormat is set to `migrating` it will return an expression that would allow handling both `floats` and `integers`.
//    Used when migrating from Prometheus 2 to 3.
// If the value passed in is a string, we won't touch it at all
local representLe(histogramApdex, value) =
  if histogramApdex.metricsFormat == 'prometheus' then
    { le: prometheusFloatValue(value) }
  else if histogramApdex.metricsFormat == 'migrating' then
    local possibleValues = std.set([escapeRegexpDecimal(value), escapeRegexpDecimal(prometheusFloatValue(value))]);
    { le: { oneOf: possibleValues } }
  else
    error 'not a a known histogramApdex.metricsFormat: %s, use one of %s' % [histogramApdex.metricsFormat, ['prometheus', 'migrating']];

// A double threshold apdex score only has both SATISFACTORY threshold and TOLERABLE thresholds
local generateDoubleThresholdApdexNumeratorQuery(histogramApdex, additionalSelectors, rangeInterval, offset, aggregationFunction=null, aggregationLabels=[], withoutLabels=[]) =
  local satisfiedQuery = generateApdexComponentRateQuery(histogramApdex, additionalSelectors, rangeInterval, representLe(histogramApdex, histogramApdex.satisfiedThreshold), aggregationFunction=aggregationFunction, aggregationLabels=aggregationLabels, withoutLabels=withoutLabels, offset=offset);
  local toleratedQuery = generateApdexComponentRateQuery(histogramApdex, additionalSelectors, rangeInterval, representLe(histogramApdex, histogramApdex.toleratedThreshold), aggregationFunction=aggregationFunction, aggregationLabels=aggregationLabels, withoutLabels=withoutLabels, offset=offset);

  |||
    (
      %(satisfied)s
      +
      %(tolerated)s
    )
    /
    2
  ||| % {
    satisfied: strings.indent(satisfiedQuery, 2),
    tolerated: strings.indent(toleratedQuery, 2),
  };

local generateApdexNumeratorQuery(histogramApdex, additionalSelectors, rangeInterval, offset, aggregationFunction=null, aggregationLabels=[], histogramRates=false, withoutLabels=[]) =
  if histogramRates then
    generateApdexComponentRateQuery(
      histogramApdex,
      additionalSelectors,
      rangeInterval,
      {},
      aggregationFunction=aggregationFunction,
      aggregationLabels=aggregationLabels,
      withoutLabels=withoutLabels,
      offset=offset
    )
  else if histogramApdex.toleratedThreshold == null then
    // A single threshold apdex score only has a SATISFACTORY threshold, no TOLERABLE threshold
    generateApdexComponentRateQuery(
      histogramApdex,
      additionalSelectors,
      rangeInterval,
      representLe(histogramApdex, histogramApdex.satisfiedThreshold),
      aggregationFunction=aggregationFunction,
      aggregationLabels=aggregationLabels,
      withoutLabels=withoutLabels,
      offset=offset
    )
  else
    generateDoubleThresholdApdexNumeratorQuery(
      histogramApdex,
      additionalSelectors,
      rangeInterval,
      aggregationFunction=aggregationFunction,
      aggregationLabels=aggregationLabels,
      withoutLabels=withoutLabels,
      offset=offset
    );

local generateApdexScoreQuery(histogramApdex, aggregationLabels, additionalSelectors, rangeInterval, aggregationFunction=null, withoutLabels=[]) =
  local numeratorQuery = generateApdexNumeratorQuery(histogramApdex, additionalSelectors, rangeInterval, aggregationFunction=aggregationFunction, aggregationLabels=aggregationLabels, withoutLabels=withoutLabels);
  local weightQuery = generateApdexComponentRateQuery(histogramApdex, additionalSelectors, rangeInterval, { le: '+Inf' }, aggregationFunction=aggregationFunction, aggregationLabels=aggregationLabels, withoutLabels=withoutLabels);

  |||
    %(numeratorQuery)s
    /
    (
      %(weightQuery)s > 0
    )
  ||| % {
    numeratorQuery: strings.chomp(numeratorQuery),
    weightQuery: strings.indent(strings.chomp(weightQuery), 2),
  };

local generatePercentileLatencyQuery(histogram, percentile, aggregationLabels, additionalSelectors, rangeInterval, withoutLabels=[]) =
  local aggregationLabelsWithLe = aggregations.join([aggregationLabels, 'le']);
  local aggregatedRateQuery = generateApdexComponentRateQuery(histogram, additionalSelectors, rangeInterval, aggregationFunction='sum', aggregationLabels=aggregationLabelsWithLe, withoutLabels=withoutLabels);

  |||
    histogram_quantile(
      %(percentile)f,
      %(aggregatedRateQuery)s
    )
  ||| % {
    percentile: percentile,
    aggregatedRateQuery: strings.indent(strings.chomp(aggregatedRateQuery), 2),
  };


local generateApdexAttributionQuery(histogram, selector, rangeInterval, aggregationLabel, withoutLabels=[]) =
  |||
    (
      (
        %(splitTotalQuery)s
        -
        (
          %(numeratorQuery)s
        )
      )
      / ignoring(%(aggregationLabel)s) group_left()
      (
        %(aggregatedTotalQuery)s
      )
    ) > 0
  ||| % {
    splitTotalQuery: generateApdexComponentRateQuery(histogram, selector, rangeInterval, { le: '+Inf' }, aggregationFunction='sum', aggregationLabels=[aggregationLabel], withoutLabels=withoutLabels, offset=null),
    numeratorQuery: generateApdexNumeratorQuery(histogram, selector, rangeInterval, aggregationFunction='sum', aggregationLabels=[aggregationLabel], withoutLabels=withoutLabels, offset=null),
    aggregationLabel: aggregationLabel,
    aggregatedTotalQuery: generateApdexComponentRateQuery(histogram, selector, rangeInterval, { le: '+Inf' }, aggregationFunction='sum', aggregationLabels=[], withoutLabels=withoutLabels, offset=null),
  };

{
  histogramApdex(
    histogram,
    rangeVectorFunction='rate',
    selector={},
    satisfiedThreshold=null,
    toleratedThreshold=null,
    metricsFormat='prometheus',
    unit='s',
    useRecordingRuleRegistry=true
  ):: metric.new({
    histogram: histogram,
    rangeVectorFunction: rangeVectorFunction,
    selector: selector,
    satisfiedThreshold: satisfiedThreshold,
    toleratedThreshold: toleratedThreshold,
    metricsFormat: metricsFormat,
    unit: unit,
    useRecordingRuleRegistry:: useRecordingRuleRegistry,

    apdexQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[])::
      generateApdexScoreQuery(
        self,
        aggregationLabels,
        selector,
        rangeInterval,
        aggregationFunction='sum',
        withoutLabels=withoutLabels,
      ),

    /* apdexSuccessRateQuery measures the rate at which apdex successes occur */
    apdexSuccessRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      generateApdexNumeratorQuery(self, selector, rangeInterval, aggregationFunction='sum', aggregationLabels=aggregationLabels, withoutLabels=withoutLabels, offset=offset),

    apdexWeightQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      generateApdexComponentRateQuery(self, selector, rangeInterval, { le: '+Inf' }, aggregationFunction='sum', aggregationLabels=aggregationLabels, withoutLabels=withoutLabels, offset=offset),

    percentileLatencyQuery(percentile, aggregationLabels, selector, rangeInterval, withoutLabels=[])::
      generatePercentileLatencyQuery(self, percentile, aggregationLabels, selector, rangeInterval, withoutLabels=withoutLabels),

    // This is used to combine multiple apdex scores for a combined percentileLatencyQuery
    aggregatedRateQuery(aggregationLabels, selector, rangeInterval, withoutLabels=[], offset=null)::
      generateApdexComponentRateQuery(self, selector, rangeInterval, aggregationFunction='sum', aggregationLabels=aggregationLabels, withoutLabels=withoutLabels, offset=offset),

    describe()::
      local s = self;
      // TODO: don't assume the metric is in seconds!
      if s.toleratedThreshold == null then
        '%gs' % [s.satisfiedThreshold]
      else
        '%gs/%gs' % [s.satisfiedThreshold, s.toleratedThreshold],

    // The preaggregated numerator expression
    // used for combinations
    apdexNumerator(selector, rangeInterval, histogramRates=false, withoutLabels=[])::
      generateApdexNumeratorQuery(self, selector, rangeInterval, aggregationFunction=null, aggregationLabels=[], histogramRates=histogramRates, withoutLabels=withoutLabels, offset=null),

    // The preaggregated denominator expression
    // used for combinations
    apdexDenominator(selector, rangeInterval, withoutLabels=[])::
      generateApdexComponentRateQuery(self, selector, rangeInterval, { le: '+Inf' }, aggregationFunction=null, aggregationLabels=[], withoutLabels=withoutLabels),

    apdexAttribution(aggregationLabel, selector, rangeInterval, withoutLabels=[])::
      generateApdexAttributionQuery(self, selector, rangeInterval, aggregationLabel=aggregationLabel, withoutLabels=withoutLabels),
  } + metricLabelsSelectorsMixin(
    selector, [histogram], labels=std.objectFields(selector) + ['le']
  )),
}
