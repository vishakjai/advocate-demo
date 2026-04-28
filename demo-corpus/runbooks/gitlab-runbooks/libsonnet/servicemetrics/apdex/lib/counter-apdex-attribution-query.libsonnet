local strings = import 'utils/strings.libsonnet';

{
  attributionQuery(counterApdex, aggregationLabel, selector, rangeInterval, withoutLabels)::
    |||
      (
        (
          %(splitTotalQuery)s
          -
          %(splitSuccessRateQuery)s
        )
        / ignoring (%(aggregationLabel)s) group_left()
        (
          %(aggregatedTotalQuery)s
        )
      ) > 0
    ||| % {
      splitTotalQuery: strings.indent(counterApdex.apdexWeightQuery([aggregationLabel], selector, rangeInterval, withoutLabels=withoutLabels), 4),
      splitSuccessRateQuery: strings.indent(counterApdex.apdexSuccessRateQuery([aggregationLabel], selector, rangeInterval, withoutLabels=withoutLabels), 4),
      aggregationLabel: aggregationLabel,
      aggregatedTotalQuery: strings.indent(counterApdex.apdexWeightQuery([], selector, rangeInterval, withoutLabels=withoutLabels), 4),
    },
}
