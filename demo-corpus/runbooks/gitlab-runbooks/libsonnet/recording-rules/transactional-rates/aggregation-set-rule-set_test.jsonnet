local underTest = import './aggregation-set-rule-set.libsonnet';
local AggregationSet = (import 'servicemetrics/aggregation-set.libsonnet').AggregationSet;
local test = import 'test.libsonnet';

local source = AggregationSet({
  id: 'component',
  name: 'Prometheus Component SLI Metrics',
  intermediateSource: true,
  selector: { monitor: 'default' },
  labels: ['type', 'component', 'other'],
  supportedBurnRates: ['5m', '30m', '1h'],
  metricFormats: {
    errorRates: 'gitlab_component_error:rates_%s',
    apdexRates: 'gitlab_component_apdex:rates_%s',
  },
});

local target = AggregationSet({
  id: 'component',
  name: 'Global Component SLI Metrics',
  intermediateSource: false,
  selector: { monitor: 'global' },
  labels: ['type', 'component'],
  supportedBurnRates: ['5m', '30m', '1h', '6h'],
  metricFormats: {
    errorRates: 'gitlab_component_error:rates_%s',
    apdexRates: 'gitlab_component_apdex:rates_%s',
  },
  aggregationFilter: 'service',
  offset: '30s',
  upscaleLongerBurnRates: true,
});

test.suite({
  testRuleSetWithoutUpscaling: {
    actual: underTest(source, target, '5m'),
    expect: [
      {
        expr: |||
          sum by (type,component,recorded_rate) (
            (gitlab_component_error:rates_5m{monitor="default"} offset 30s) and on(component, type) (gitlab_component_service:mapping{monitor="global",service_aggregation="yes"})
          )
        |||,
        record: 'gitlab_component_error:rates_5m',
      },
      {
        expr: |||
          sum by (type,component,recorded_rate) (
            (gitlab_component_apdex:rates_5m{monitor="default"} offset 30s) and on(component, type) (gitlab_component_service:mapping{monitor="global",service_aggregation="yes"})
          )
        |||,
        record: 'gitlab_component_apdex:rates_5m',
      },
    ],
  },
  testRuleSetWithUpscaling: {
    actual: underTest(source, target, '6h'),
    expect: [
      {
        expr: |||
          sum by (type,component,recorded_rate) (
            avg_over_time(gitlab_component_error:rates_1h{monitor="global"}[6h] offset 30s) and on(component, type) (gitlab_component_service:mapping{monitor="global",service_aggregation="yes"})
          )
        |||,
        record: 'gitlab_component_error:rates_6h',
      },
      {
        expr: |||
          sum by (type,component,recorded_rate) (
            avg_over_time(gitlab_component_apdex:rates_1h{monitor="global"}[6h] offset 30s) and on(component, type) (gitlab_component_service:mapping{monitor="global",service_aggregation="yes"})
          )
        |||,
        record: 'gitlab_component_apdex:rates_6h',
      },
    ],
  },
})
