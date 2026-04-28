local selectors = import 'promql/selectors.libsonnet';

local weeklyOperationRules(aggregationSet, extraSelector, burnRateMetricGetFn, serviceMetric, disableMetric) =
  local metric = burnRateMetricGetFn('5m', required=true);
  local selector = aggregationSet.selector + extraSelector;
  local selectorWithoutEnv = selectors.without(selector, ['env']);
  [
    {
      record: '%(serviceMetric)s:rate:avg_over_time_1w' % { serviceMetric: serviceMetric },
      expr: |||
        avg_over_time(%(metric)s{%(selector)s}[1w])
        unless on(tier, type)
        gitlab_service:mapping:%(disableMetric)s{%(selectorWithoutEnv)s}
      ||| % {
        metric: metric,
        selector: selectors.serializeHash(selector),
        selectorWithoutEnv: selectors.serializeHash(selectorWithoutEnv),
        disableMetric: disableMetric,
      },
    },
    {
      record: '%(serviceMetric)s:rate:stddev_over_time_1w' % { serviceMetric: serviceMetric },
      expr: |||
        stddev_over_time(%(metric)s{%(selector)s}[1w])
        unless on(tier, type)
        gitlab_service:mapping:%(disableMetric)s{%(selectorWithoutEnv)s}
      ||| % {
        metric: metric,
        selector: selectors.serializeHash(selector),
        selectorWithoutEnv: selectors.serializeHash(selectorWithoutEnv),
        disableMetric: disableMetric,
      },
    },
  ];

local weeklyPredictionRules(aggregationSet, extraSelector, burnRateMetricGetFn, serviceMetric) =
  local burnRateMetric = burnRateMetricGetFn('1h', required=true);
  local selector = extraSelector + aggregationSet.selector;
  [{
    record: '%(serviceMetric)s:rate:prediction' % { serviceMetric: serviceMetric },
    expr: |||
      quantile(0.5,
        label_replace(
          %(burnRateMetric)s{%(selector)s} offset 10050m # 1 week - 30mins
          + delta(%(serviceMetric)s:rate:avg_over_time_1w{%(selector)s}[1w])
          , "p", "1w", "", "")
        or
        label_replace(
          %(burnRateMetric)s{%(selector)s} offset 20130m # 2 weeks - 30mins
          + delta(%(serviceMetric)s:rate:avg_over_time_1w{%(selector)s}[2w])
          , "p", "2w", "", "")
        or
        label_replace(
          %(burnRateMetric)s{%(selector)s} offset 30210m # 3 weeks - 30mins
          + delta(%(serviceMetric)s:rate:avg_over_time_1w{%(selector)s}[3w])
          , "p", "3w", "", "")
      )
      without (p)
    ||| % {
      burnRateMetric: burnRateMetric,
      selector: selectors.serializeHash(selector),
      serviceMetric: serviceMetric,
    },
  }];
{
  recordingRuleGroupsFor(service, aggregationSet, burnRateMetricGetFn, metricName, serviceMetric, disableMetric, extraSelector={}): [
    {
      name: '%s %s weekly statistics: %s' % [service, metricName, extraSelector],
      interval: '5m',
      rules: weeklyOperationRules(aggregationSet, extraSelector, burnRateMetricGetFn, serviceMetric, disableMetric),
    },
    {
      name: '%s %s weekly prediction values: %s' % [service, metricName, extraSelector],
      interval: '5m',
      rules: weeklyPredictionRules(aggregationSet, extraSelector, burnRateMetricGetFn, serviceMetric),
    },
  ],
}
