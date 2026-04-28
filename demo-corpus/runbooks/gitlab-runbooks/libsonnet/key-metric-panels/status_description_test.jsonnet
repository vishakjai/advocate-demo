local sliDefinition = import './servicemetrics/service_level_indicator_definition.libsonnet';
local underTest = import './status_description.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local test = import 'test.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;

local aSet = aggregationSet.AggregationSet({
  name: 'source',
  intermediateSource: true,
  labels: ['a', 'b'],
  selector: { hello: 'world' },
  supportedBurnRates: ['5m', '1h', '30m', '6h'],
  metricFormats: {
    opsRate: 'ops_rate_%s',
    errorRate: 'error_rate_%s',
    errorRatio: 'error_ratio_%s',

    apdexRatio: 'apdex_ratio_%s',
    apdexSuccessRate: 'apdex_success_%s',
    apdexWeight: 'apdex_weight_%s',

    // Confidence Interval Ratios
    apdexConfidenceRatio: 'apdex:confidence:ratio_%s',
    errorConfidenceRatio: 'error:confidence:ratio_%s',
  },
});

local sli = sliDefinition.serviceLevelIndicatorDefinition({
  name: 'moo',
  userImpacting: true,
  useConfidenceLevelForSLIAlerts: '98%',
  description: |||
    Blah
  |||,

  requestRate: rateMetric(
    counter='gitlab_workhorse_http_requests_total',
    selector={}
  ),

  errorRate: rateMetric(
    counter='gitlab_workhorse_http_requests_total',
    selector={
      code: { re: '^5.*' },
    }
  ),

  significantLabels: ['fqdn'],
  featureCategory: 'not_owned',
}).initServiceLevelIndicatorWithName('sli', {});

test.suite({
  testApdexNoSLINoConfidence: {
    actual: underTest.apdexStatusQuery(
      selectorHash={ component: 'spoon' },
      aggregationSet=aSet,
      sli=null,
      fixedThreshold=null
    ),
    expect: |||
      sum(
        label_replace(
          vector(0) and on() (apdex_ratio_1h{component="spoon",hello="world"}),
          "period", "na", "", ""
        )
        or
        label_replace(
          vector(1) and on () (apdex_ratio_5m{component="spoon",hello="world"} < on(tier, type, __tenant_id__) group_left() (1 - (14.4 * (1 - slo:min:events:gitlab_service_apdex:ratio{component="spoon",monitor="global"})))),
          "period", "5m", "", ""
        )
        or
        label_replace(
          vector(2) and on () (apdex_ratio_1h{component="spoon",hello="world"} < on(tier, type, __tenant_id__) group_left() (1 - (14.4 * (1 - slo:min:events:gitlab_service_apdex:ratio{component="spoon",monitor="global"})))),
          "period", "1h", "", ""
        )
        or
        label_replace(
          vector(4) and on () (apdex_ratio_30m{component="spoon",hello="world"} < on(tier, type, __tenant_id__) group_left() (1 - (6 * (1 - slo:min:events:gitlab_service_apdex:ratio{component="spoon",monitor="global"})))),
          "period", "30m", "", ""
        )
        or
        label_replace(
          vector(8) and on () (apdex_ratio_6h{component="spoon",hello="world"} < on(tier, type, __tenant_id__) group_left() (1 - (6 * (1 - slo:min:events:gitlab_service_apdex:ratio{component="spoon",monitor="global"})))),
          "period", "6h", "", ""
        )
      )
    |||,
  },

  testErrorNoSLINoConfidence: {
    actual: underTest.errorRateStatusQuery(
      selectorHash={ component: 'spoon' },
      aggregationSet=aSet,
      sli=null,
      fixedThreshold=null
    ),
    expect: |||
      sum(
        label_replace(
          vector(0) and on() (error_ratio_1h{component="spoon",hello="world"}),
          "period", "na", "", ""
        )
        or
        label_replace(
          vector(1) and on () (error_ratio_5m{component="spoon",hello="world"} > on(tier, type, __tenant_id__) group_left() (14.4 * slo:max:events:gitlab_service_errors:ratio{component="spoon",monitor="global"})),
          "period", "5m", "", ""
        )
        or
        label_replace(
          vector(2) and on () (error_ratio_1h{component="spoon",hello="world"} > on(tier, type, __tenant_id__) group_left() (14.4 * slo:max:events:gitlab_service_errors:ratio{component="spoon",monitor="global"})),
          "period", "1h", "", ""
        )
        or
        label_replace(
          vector(4) and on () (error_ratio_30m{component="spoon",hello="world"} > on(tier, type, __tenant_id__) group_left() (6 * slo:max:events:gitlab_service_errors:ratio{component="spoon",monitor="global"})),
          "period", "30m", "", ""
        )
        or
        label_replace(
          vector(8) and on () (error_ratio_6h{component="spoon",hello="world"} > on(tier, type, __tenant_id__) group_left() (6 * slo:max:events:gitlab_service_errors:ratio{component="spoon",monitor="global"})),
          "period", "6h", "", ""
        )
      )
    |||,
  },

  testApdexWithSLIWithConfidence: {
    actual: underTest.apdexStatusQuery(
      selectorHash={ component: 'spoon' },
      aggregationSet=aSet,
      sli=sli,
      fixedThreshold=null
    ),
    expect: |||
      sum(
        label_replace(
          vector(0) and on() (apdex:confidence:ratio_1h{component="spoon",confidence="98%",hello="world"}),
          "period", "na", "", ""
        )
        or
        label_replace(
          vector(1) and on () (apdex:confidence:ratio_5m{component="spoon",confidence="98%",hello="world"} < on(tier, type, __tenant_id__) group_left() (1 - (14.4 * (1 - slo:min:events:gitlab_service_apdex:ratio{component="spoon",monitor="global"})))),
          "period", "5m", "", ""
        )
        or
        label_replace(
          vector(2) and on () (apdex:confidence:ratio_1h{component="spoon",confidence="98%",hello="world"} < on(tier, type, __tenant_id__) group_left() (1 - (14.4 * (1 - slo:min:events:gitlab_service_apdex:ratio{component="spoon",monitor="global"})))),
          "period", "1h", "", ""
        )
        or
        label_replace(
          vector(4) and on () (apdex:confidence:ratio_30m{component="spoon",confidence="98%",hello="world"} < on(tier, type, __tenant_id__) group_left() (1 - (6 * (1 - slo:min:events:gitlab_service_apdex:ratio{component="spoon",monitor="global"})))),
          "period", "30m", "", ""
        )
        or
        label_replace(
          vector(8) and on () (apdex:confidence:ratio_6h{component="spoon",confidence="98%",hello="world"} < on(tier, type, __tenant_id__) group_left() (1 - (6 * (1 - slo:min:events:gitlab_service_apdex:ratio{component="spoon",monitor="global"})))),
          "period", "6h", "", ""
        )
      )
    |||,
  },


  testErrorWithSLIWithConfidence: {
    actual: underTest.errorRateStatusQuery(
      selectorHash={ component: 'spoon' },
      aggregationSet=aSet,
      sli=sli,
      fixedThreshold=null
    ),
    expect: |||
      sum(
        label_replace(
          vector(0) and on() (error:confidence:ratio_1h{component="spoon",confidence="98%",hello="world"}),
          "period", "na", "", ""
        )
        or
        label_replace(
          vector(1) and on () (error:confidence:ratio_5m{component="spoon",confidence="98%",hello="world"} > on(tier, type, __tenant_id__) group_left() (14.4 * slo:max:events:gitlab_service_errors:ratio{component="spoon",monitor="global"})),
          "period", "5m", "", ""
        )
        or
        label_replace(
          vector(2) and on () (error:confidence:ratio_1h{component="spoon",confidence="98%",hello="world"} > on(tier, type, __tenant_id__) group_left() (14.4 * slo:max:events:gitlab_service_errors:ratio{component="spoon",monitor="global"})),
          "period", "1h", "", ""
        )
        or
        label_replace(
          vector(4) and on () (error:confidence:ratio_30m{component="spoon",confidence="98%",hello="world"} > on(tier, type, __tenant_id__) group_left() (6 * slo:max:events:gitlab_service_errors:ratio{component="spoon",monitor="global"})),
          "period", "30m", "", ""
        )
        or
        label_replace(
          vector(8) and on () (error:confidence:ratio_6h{component="spoon",confidence="98%",hello="world"} > on(tier, type, __tenant_id__) group_left() (6 * slo:max:events:gitlab_service_errors:ratio{component="spoon",monitor="global"})),
          "period", "6h", "", ""
        )
      )
    |||,
  },
})
