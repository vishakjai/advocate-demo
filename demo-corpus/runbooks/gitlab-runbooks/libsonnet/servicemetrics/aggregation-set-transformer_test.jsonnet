local aggregationSetTransformer = import './aggregation-set-transformer.libsonnet';
local aggregationSet = import './aggregation-set.libsonnet';
local test = import 'test.libsonnet';

local sourceSet = aggregationSet.AggregationSet({
  id: 'source',
  name: 'source',
  intermediateSource: true,
  labels: ['a', 'b'],
  selector: { hello: 'world' },
  metricFormats: {
    opsRate: 'source_%s_ops_rate',
    errorRate: 'source_%s_error_rate',
    errorRatio: 'source_%s_error_ratio',
  },
});

local targetSet = aggregationSet.AggregationSet({
  id: 'target',
  name: 'target',
  intermediateSource: true,
  supportedBurnRates: ['1h', '6h'],
  upscaleLongerBurnRates: true,
  labels: ['a', 'b'],
  selector: {},
  metricFormats: {
    opsRate: 'target_%s_ops_rate',
    errorRate: 'target_%s_error_rate',
  },
});

test.suite({
  testGenerateRecordingRuleGroups: {
    actual: aggregationSetTransformer.generateRecordingRuleGroups(sourceSet, targetSet),
    expect: [
      {
        interval: '1m',
        name: 'target (fast burn)',
        rules: [
          {
            expr: |||
              sum by (a,b) (
                (source_1h_error_rate{hello="world"} >= 0)
              )
            |||,
            record: 'target_1h_error_rate',
          },
          {
            expr: |||
              sum by (a,b) (
                (source_1h_ops_rate{hello="world"} >= 0)
              )
            |||,
            record: 'target_1h_ops_rate',
          },
        ],
      },
      {
        interval: '2m',
        name: 'target (slow burn)',
        rules: [{
          expr: |||
            sum by (a,b) (
              avg_over_time(target_1h_error_rate{}[6h])
            )
          |||,
          record: 'target_6h_error_rate',
        }, {
          expr: |||
            sum by (a,b) (
              avg_over_time(target_1h_ops_rate{}[6h])
            )
          |||,
          record: 'target_6h_ops_rate',
        }],
      },
    ],
  },
  testGenerateRecordingRuleGroupsExtras: {
    actual: aggregationSetTransformer.generateRecordingRuleGroups(sourceSet, targetSet, { partial_response_strategy: 'warn' }),
    expectAll: function(group) group.partial_response_strategy == 'warn',
  },
})
