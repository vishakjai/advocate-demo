local addStaticLabel = (import 'promql/labels.libsonnet').addStaticLabel;
local strings = import 'utils/strings.libsonnet';

local recordedRatesLabel = 'recorded_rate';
local apdexRatesLabels = {
  numerator: 'success_rate',
  denominator: 'apdex_weight',
};
local errorRatesLabels = {
  numerator: 'error_rate',
  denominator: 'ops_rate',
};


local transactionalExpression(numeratorExpr, denominatorExpr, labelDefinition) =
  |||
    %(wrappedNumerator)s
    or
    %(wrappedDenominator)s
  ||| % {
    wrappedNumerator: strings.chomp(addStaticLabel(recordedRatesLabel, labelDefinition.numerator, numeratorExpr)),
    wrappedDenominator: strings.chomp(addStaticLabel(recordedRatesLabel, labelDefinition.denominator, denominatorExpr)),
  };

{
  recordedRatesLabel: recordedRatesLabel,
  apdexRatesExpr(apdexSuccessRateExpr, apdexWeightExpr)::
    transactionalExpression(apdexSuccessRateExpr, apdexWeightExpr, apdexRatesLabels),
  errorRatesExpr(errorRateExpr, opsRateExpr)::
    local guardedErrorRateExpr = |||
      %(errorRateExpr)s
      or
      (
        0 * %(opsRateExpr)s
      )
    ||| % {
      errorRateExpr: errorRateExpr,
      opsRateExpr: strings.indent(opsRateExpr, 2),
    };
    transactionalExpression(guardedErrorRateExpr, opsRateExpr, errorRatesLabels),
  aggregationSetRuleSet: (import 'aggregation-set-rule-set.libsonnet'),
}
