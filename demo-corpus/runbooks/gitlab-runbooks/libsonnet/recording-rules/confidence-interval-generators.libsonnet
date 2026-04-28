local selectors = import 'promql/selectors.libsonnet';
local durationParser = import 'utils/duration-parser.libsonnet';
local wilsonScore = import 'wilson-score/wilson-score.libsonnet';

{
  // Generates a Error Ratio with the specified confidence level.
  // The series returned will be the LOWER confidence band for
  // the error rate, at the given RPS.
  errorRatioConfidenceInterval(aggregationSet, burnRate, extraSelector={}, staticLabels={}, confidenceLevel=null)::
    local targetMetric = aggregationSet.getErrorRatioConfidenceIntervalMetricForBurnRate(burnRate);
    local errorRateMetric = aggregationSet.getErrorRateMetricForBurnRate(burnRate);
    local opsRateMetric = aggregationSet.getOpsRateMetricForBurnRate(burnRate);
    local allStaticLabels = aggregationSet.recordingRuleStaticLabels + staticLabels + { confidence: confidenceLevel };

    if targetMetric == null || errorRateMetric == null || opsRateMetric == null then
      []
    else
      [{
        record: targetMetric,
        labels: aggregationSet.recordingRuleStaticLabels + staticLabels + { confidence: confidenceLevel },

        // For error rates, we use the lower interval boundary value
        expr: wilsonScore.lower(
          scoreRate='%s{%s}' % [errorRateMetric, selectors.serializeHash(extraSelector)],
          totalRate='%s{%s}' % [opsRateMetric, selectors.serializeHash(extraSelector)],
          windowInSeconds=durationParser.toSeconds(burnRate),
          confidence=confidenceLevel
        ),
      }],

  // Generates an Apdex Ratio with the specified confidence level.
  // The series returned will be the UPPER confidence band for
  // the error rate, at the given RPS.
  apdexRatioConfidenceInterval(aggregationSet, burnRate, extraSelector={}, staticLabels={}, confidenceLevel=null)::
    local targetMetric = aggregationSet.getApdexRatioConfidenceIntervalMetricForBurnRate(burnRate);
    local successMetric = aggregationSet.getApdexSuccessRateMetricForBurnRate(burnRate);
    local totalMetric = aggregationSet.getApdexWeightMetricForBurnRate(burnRate);

    if targetMetric == null || successMetric == null || totalMetric == null then
      []
    else
      [{
        record: targetMetric,
        labels: aggregationSet.recordingRuleStaticLabels + staticLabels + { confidence: confidenceLevel },

        // For apdex rates, we use the upper interval boundary value
        expr: wilsonScore.upper(
          scoreRate='%s{%s}' % [successMetric, selectors.serializeHash(extraSelector)],
          totalRate='%s{%s}' % [totalMetric, selectors.serializeHash(extraSelector)],
          windowInSeconds=durationParser.toSeconds(burnRate),
          confidence=confidenceLevel
        ),
      }],
}
