local underTest = import './aggregation-set-reflected-ratio-rule-set.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';

local fixture = aggregationSet.AggregationSet({
  id: 'component',
  name: 'Global Component SLI Metrics',
  intermediateSource: false,
  selector: {},
  labels: ['type', 'component'],
  supportedBurnRates: ['5m', '30m', '1h', '6h'],
  offset: '5s',
  metricFormats: {
    apdexSuccessRate: 'apdex_success_%s',
    apdexWeight: 'apdex_weight_%s',
    apdexRatio: 'apdex_ratio_%s',
    opsRate: 'ops_rate_%s',
    errorRate: 'error_rate_%s',
    errorRatio: 'error_ratio_%s',
  },
});

test.suite({
  testErrorRatioRuleSet: {
    actual: underTest.aggregationSetErrorRatioReflectedRuleSet(fixture, '5m'),
    expect: [{
      record: 'error_ratio_5m',
      expr: |||
        sum by (type,component) (
          error_rate_5m{} offset 5s
        )
        /
        sum by (type,component) (
          ops_rate_5m{} offset 5s
        )
      |||,
    }],
  },

  // Passing a selector and static labels has the following consequences:
  // 1. The selector is applied to the source of the aggregation for the ratio
  // 2. Static labels become part of the selector for the aggregationSet,
  // 3. Static labels are filtered out of the aggregation labels
  testErrorRatioRuleSetWithSelectorAndStaticLabels: {
    actual: underTest.aggregationSetErrorRatioReflectedRuleSet(fixture, '5m', { selector: 'hello' }, { type: 'web', static: 'label' }),
    expect: [{
      record: 'error_ratio_5m',
      labels: { static: 'label', type: 'web' },
      expr: |||
        sum by (component) (
          error_rate_5m{selector="hello",static="label",type="web"} offset 5s
        )
        /
        sum by (component) (
          ops_rate_5m{selector="hello",static="label",type="web"} offset 5s
        )
      |||,
    }],
  },

  testApdexRatioRuleSet: {
    actual: underTest.aggregationSetApdexRatioReflectedRuleSet(fixture, '5m'),
    expect: [{
      record: 'apdex_ratio_5m',
      expr: |||
        sum by (type,component) (
          apdex_success_5m{} offset 5s
        )
        /
        sum by (type,component) (
          apdex_weight_5m{} offset 5s
        )
      |||,
    }],
  },
})
