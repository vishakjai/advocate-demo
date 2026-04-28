local availabilityPromql = import './availability-promql.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local test = import 'test.libsonnet';

test.suite({
  local keyServices = ['webservice', 'registry'],
  local testSet = aggregationSet.AggregationSet({
    id: 'service',
    name: 'Global Service-Aggregated Metrics',
    intermediateSource: false,  // Used in dashboards and alerts
    selector: { monitor: 'global' },
    labels: ['env', 'environment', 'type', 'stage'],
    metricFormats: {
      apdexSuccessRate: 'gitlab_service_apdex:success:rate_%s',
      apdexWeight: 'gitlab_service_apdex:weight:score_%s',
      opsRate: 'gitlab_service_ops:rate_%s',
      errorRate: 'gitlab_service_errors:rate_%s',
    },
  }),

  local testPromql = availabilityPromql.new(keyServices, testSet, extraSelector={ env: 'gprd' }),

  testSuccessRate: {
    actual: testPromql.successRate,
    expect: |||
      (
        sum by(env,environment,type,stage) (
          gitlab_service_apdex:success:rate_1h{env="gprd",type=~"registry|webservice"}
        )
        +
        sum by (env,environment,type,stage)(
          gitlab_service_ops:rate_1h{env="gprd",type=~"registry|webservice"} - gitlab_service_errors:rate_1h{env="gprd",type=~"registry|webservice"}
        )
      )
    |||,
  },

  testOpsRate: {
    actual: testPromql.opsRate,
    expect: |||
      (
        sum by(env,environment,type,stage) (
          gitlab_service_ops:rate_1h{env="gprd",type=~"registry|webservice"}
        )
        +
        sum by (env,environment,type,stage) (
          gitlab_service_apdex:weight:score_1h{env="gprd",type=~"registry|webservice"}
        )
      )
    |||,
  },

  local testPromqlAllServices = availabilityPromql.new('*', testSet, extraSelector={ env: 'gprd' }),
  testSuccessRateAllServices: {
    actual: testPromqlAllServices.successRate,
    expect: |||
      (
        sum by(env,environment,type,stage) (
          gitlab_service_apdex:success:rate_1h{env="gprd"}
        )
        +
        sum by (env,environment,type,stage)(
          gitlab_service_ops:rate_1h{env="gprd"} - gitlab_service_errors:rate_1h{env="gprd"}
        )
      )
    |||,
  },

  testOpsRateAllServices: {
    actual: testPromqlAllServices.opsRate,
    expect: |||
      (
        sum by(env,environment,type,stage) (
          gitlab_service_ops:rate_1h{env="gprd"}
        )
        +
        sum by (env,environment,type,stage) (
          gitlab_service_apdex:weight:score_1h{env="gprd"}
        )
      )
    |||,
  },

  testRateRules: {
    actual: std.map(function(rule) rule.record, testPromql.rateRules),
    expect: ['gitlab:availability:ops:rate_1h', 'gitlab:availability:success:rate_1h'],
  },

  testAvailabilityRatio: {
    actual: testPromql.availabilityRatio(['type'], { environment: 'gprd' }, '30d', ['api', 'web']),
    expect: |||
      sum by (type) (
        sum_over_time(gitlab:availability:success:rate_1h{environment="gprd",type=~"api|web"}[30d])
      )
      /
      sum by (type) (
        sum_over_time(gitlab:availability:ops:rate_1h{environment="gprd",type=~"api|web"}[30d])
      )
    |||,
  },

  testWeightedAvailabilityQuery: {
    local serviceWeights = { web: '$web_weight', api: '$api_weight' },
    actual: testPromql.weightedAvailabilityQuery(serviceWeights, { env: 'gprd' }, '$__range'),
    expect: |||
      sum(
        sum by (type)(
          sum_over_time(gitlab:availability:success:rate_1h{env="gprd",type="api"}[$__range]) * $api_weight
        )
        or
        sum by (type)(
          sum_over_time(gitlab:availability:success:rate_1h{env="gprd",type="web"}[$__range]) * $web_weight
        )
      )
      /
      sum(
        sum by (type)(
          sum_over_time(gitlab:availability:ops:rate_1h{env="gprd",type="api"}[$__range]) * $api_weight
        )
        or
        sum by (type)(
          sum_over_time(gitlab:availability:ops:rate_1h{env="gprd",type="web"}[$__range]) * $web_weight
        )
      )
    |||,
  },
})
