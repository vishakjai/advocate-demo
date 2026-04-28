local underTest = import './service_level_indicator_definition.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';
local test = import 'test.libsonnet';
local successCounterApdex = metricsCatalog.successCounterApdex;
local rateMetric = metricsCatalog.rateMetric;
local nullRegistryConfig = { config: { recordingRuleRegistry: recordingRuleRegistry.nullRegistry } };

local testSli = underTest.serviceLevelIndicatorDefinition({
  significantLabels: [],
  userImpacting: false,
  requestRate: rateMetric('some_total_count') + nullRegistryConfig,
  apdex: successCounterApdex('some_apdex_success_total_count', 'some_apdex_total_count') + nullRegistryConfig,
  errorRate: rateMetric('some_error_total_count') + nullRegistryConfig,
}).initServiceLevelIndicatorWithName('test_sli', {});

local ratesAggregationSet = aggregationSet.AggregationSet({
  name: 'source',
  intermediateSource: true,
  labels: ['a', 'b'],
  selector: { hello: 'world' },
  metricFormats: {
    opsRate: 'source_ops:rate_%s',

    errorRate: 'source_error:rate_%s',
    errorRates: 'source_error:rates_%s',

    apdexRates: 'source_apdex:rates_%s',
    apdexSuccessRate: 'source_apdex:weight_rate_%s',
    apdexWeight: 'source_apdex:weight_rate_%s',
  },
  offset: '2s',
});

test.suite({
  testGenerateApdexRecordingRules: {
    actual: testSli.generateApdexRecordingRules('5m', ratesAggregationSet, { hello: 'world' }, { selector: 'is-present' }),
    expect: [
      {
        expr: |||
          sum by (a,b) (
            rate(some_apdex_success_total_count{selector="is-present"}[5m] offset 2s)
          )
        |||,
        labels: { hello: 'world' },
        record: 'source_apdex:weight_rate_5m',
      },
      {
        expr: |||
          sum by (a,b) (
            rate(some_apdex_total_count{selector="is-present"}[5m] offset 2s)
          )
        |||,
        labels: { hello: 'world' },
        record: 'source_apdex:weight_rate_5m',
      },
      {
        expr: |||
          label_replace(
            sum by (a,b) (
              rate(some_apdex_success_total_count{selector="is-present"}[5m] offset 2s)
            ),
            'recorded_rate', 'success_rate' , '', ''
          )
          or
          label_replace(
            sum by (a,b) (
              rate(some_apdex_total_count{selector="is-present"}[5m] offset 2s)
            ),
            'recorded_rate', 'apdex_weight' , '', ''
          )
        |||,
        labels: { hello: 'world' },
        record: 'source_apdex:rates_5m',
      },
    ],
  },
  testGenerateErrorRateRecordingRules: {
    actual: testSli.generateErrorRateRecordingRules('5m', ratesAggregationSet, { hello: 'world' }, { selector: 'is-present' }),
    expect: [
      {
        expr: |||
          (
            sum by (a,b) (
              rate(some_error_total_count{selector="is-present"}[5m] offset 2s)
            )
          )
          or
          (
            0 * group by(a,b) (
              source_ops:rate_5m{hello="world",selector="is-present"}
            )
          )
        |||,
        labels: { hello: 'world' },
        record: 'source_error:rate_5m',
      },
      {
        expr: |||
          label_replace(
            sum by (a,b) (
              rate(some_error_total_count{selector="is-present"}[5m] offset 2s)
            )
            or
            (
              0 * sum by (a,b) (
                rate(some_total_count{selector="is-present"}[5m] offset 2s)
              )
            ),
            'recorded_rate', 'error_rate' , '', ''
          )
          or
          label_replace(
            sum by (a,b) (
              rate(some_total_count{selector="is-present"}[5m] offset 2s)
            ),
            'recorded_rate', 'ops_rate' , '', ''
          )
        |||,
        labels: { hello: 'world' },
        record: 'source_error:rates_5m',
      },
    ],
  },
})
