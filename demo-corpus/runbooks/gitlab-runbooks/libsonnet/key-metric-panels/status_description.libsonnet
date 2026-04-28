local sliPromql = import './sli_promql.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local multiburnFactors = import 'mwmbr/multiburn_factors.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local objects = import 'utils/objects.libsonnet';
local strings = import 'utils/strings.libsonnet';

/* --------------------------------------------
 * Values are bitmapped, 0000, each bit indicates a degrades burn-rate signal
 * Bit 0: 5m
 * Bit 1: 1h
 * Bit 2: 30m
 * Bit 3: 6h
 */

local descriptionMappings = [
  /* 0: 0000 */
  {
    text: 'Healthy',
    color: 'black',
  },
  /* 1: 0001 */
  {
    text: 'Warning: 1h deteriorating',
    color: 'orange',
  },
  /* 2: 0010 */
  {
    text: 'Warning: 1h recovering',
    color: 'orange',
  },
  /* 3: 0011 */
  {
    text: 'Degraded: 1h degraded',
    color: 'red',
  },
  /* 4: 0100 */
  {
    text: 'Warning: 6h deteriorating',
    color: 'orange',
  },
  /* 5: 0101 */
  {
    text: 'Warning: 6h deteriorating, 1h deteriorating',
    color: 'orange',
  },
  /* 6: 0110 */
  {
    text: 'Warning: 6h deteriorating, 1h recovering',
    color: 'orange',
  },
  /* 7: 0111 */
  {
    text: 'Degraded: 6h deteriorating, 1h degraded',
    color: 'red',
  },
  /* 8: 1000 */
  {
    text: 'Warning: 6h recovering',
    color: 'orange',
  },
  /* 9: 1001 */
  {
    text: 'Warning: 6h recovering, 1h deteriorating',
    color: 'orange',
  },
  /* 10: 1010 */
  {
    text: 'Warning: 6h recovering, 1h recovering',
    color: 'orange',
  },
  /* 11: 1011 */
  {
    text: 'Degraded: 6h recovering, 1h degraded',
    color: 'red',
  },
  /* 12: 1100 */
  {
    text: 'Degraded: 6h degraded',
    color: 'red',
  },
  /* 13: 1101 */
  {
    text: 'Degraded: 6h degraded, 1h deteriorating',
    color: 'red',
  },
  /* 14: 1110 */
  {
    text: 'Degraded: 6h degraded, 1h recovering',
    color: 'red',
  },
  /* 15: 1111 */
  {
    text: 'Degraded: 6h degraded, 1h degraded',
    color: 'red',
  },
];

local getApdexMetric(aggregationSet, sli, duration, selectorHash) =
  local confidenceIntervalLevel =
    if sli != null && sli.usesConfidenceLevelForSLIAlerts() then
      sli.getConfidenceLevel()
    else
      null;

  local confidenceSelector =
    if confidenceIntervalLevel != null then
      aggregationSet.confidenceSelector(confidenceIntervalLevel)
    else
      {};

  local metric =
    if confidenceIntervalLevel != null then
      aggregationSet.getApdexRatioConfidenceIntervalMetricForBurnRate(duration, required=true)
    else
      aggregationSet.getApdexRatioMetricForBurnRate(duration, required=true);

  '%(metric)s{%(selector)s}' % {
    metric: metric,
    selector: selectors.serializeHash(selectorHash + aggregationSet.selector + confidenceSelector),
  };

local apdexStatusQuery(selectorHash, type, aggregationSet, sli, fixedThreshold) =
  local allSelectors = selectorHash + aggregationSet.selector;
  local expr1h = getApdexMetric(aggregationSet, sli, '1h', selectorHash);
  local expr5m = getApdexMetric(aggregationSet, sli, '5m', selectorHash);
  local expr6h = getApdexMetric(aggregationSet, sli, '6h', selectorHash);
  local expr30m = getApdexMetric(aggregationSet, sli, '30m', selectorHash);

  local sloExpression = if fixedThreshold == null then
    'on(tier, type, __tenant_id__) group_left() (1 - (%(burnrateFactor)g * (1 - slo:min:events:gitlab_service_apdex:ratio{%(slaSelector)s})))'
  else
    '(1 - (%(burnrateFactor)g * (1 - %(fixedSlo)g)))';

  local formatConfig = std.prune({
    slaSelector: selectors.serializeHash(sliPromql.sloLabels(allSelectors)),
    fixedSlo: fixedThreshold,
  });
  local sloExpr1h = sloExpression % formatConfig { burnrateFactor: multiburnFactors.errorBudgetFactorFor('1h') };
  local sloExpr6h = sloExpression % formatConfig { burnrateFactor: multiburnFactors.errorBudgetFactorFor('6h') };

  |||
    sum(
      label_replace(
        vector(0) and on() (%(expr1h)s),
        "period", "na", "", ""
      )
      or
      label_replace(
        vector(1) and on () (%(expr5m)s < %(sloExpr1h)s),
        "period", "5m", "", ""
      )
      or
      label_replace(
        vector(2) and on () (%(expr1h)s < %(sloExpr1h)s),
        "period", "1h", "", ""
      )
      or
      label_replace(
        vector(4) and on () (%(expr30m)s < %(sloExpr6h)s),
        "period", "30m", "", ""
      )
      or
      label_replace(
        vector(8) and on () (%(expr6h)s < %(sloExpr6h)s),
        "period", "6h", "", ""
      )
    )
  ||| % {
    expr1h: expr1h,
    expr5m: expr5m,
    expr6h: expr6h,
    expr30m: expr30m,
    sloExpr1h: strings.chomp(sloExpr1h),
    sloExpr6h: strings.chomp(sloExpr6h),
  };

local getErrorMetric(aggregationSet, sli, duration, selectorHash) =
  local confidenceIntervalLevel =
    if sli != null && sli.usesConfidenceLevelForSLIAlerts() then
      sli.getConfidenceLevel()
    else
      null;

  local confidenceSelector =
    if confidenceIntervalLevel != null then
      aggregationSet.confidenceSelector(confidenceIntervalLevel)
    else
      {};

  local metric =
    if confidenceIntervalLevel != null then
      aggregationSet.getErrorRatioConfidenceIntervalMetricForBurnRate(duration, required=true)
    else
      aggregationSet.getErrorRatioMetricForBurnRate(duration, required=true);

  '%(metric)s{%(selector)s}' % {
    metric: metric,
    selector: selectors.serializeHash(selectorHash + aggregationSet.selector + confidenceSelector),
  };

local errorRateStatusQuery(selectorHash, type, aggregationSet, sli, fixedThreshold) =
  local allSelectors = selectorHash + aggregationSet.selector;
  local expr1h = getErrorMetric(aggregationSet, sli, '1h', selectorHash);
  local expr5m = getErrorMetric(aggregationSet, sli, '5m', selectorHash);
  local expr6h = getErrorMetric(aggregationSet, sli, '6h', selectorHash);
  local expr30m = getErrorMetric(aggregationSet, sli, '30m', selectorHash);

  local sloExpression =
    if fixedThreshold == null then
      'on(tier, type, __tenant_id__) group_left() (%(burnrateFactor)s * slo:max:events:gitlab_service_errors:ratio{%(slaSelector)s})'
    else
      '(%(burnrateFactor)g * %(fixedSlo)g)';

  local formatConfig = std.prune({
    slaSelector: selectors.serializeHash(sliPromql.sloLabels(allSelectors)),
    fixedSlo: fixedThreshold,
  });
  local sloExpr1h = sloExpression % formatConfig { burnrateFactor: multiburnFactors.errorBudgetFactorFor('1h') };
  local sloExpr6h = sloExpression % formatConfig { burnrateFactor: multiburnFactors.errorBudgetFactorFor('6h') };

  |||
    sum(
      label_replace(
        vector(0) and on() (%(expr1h)s),
        "period", "na", "", ""
      )
      or
      label_replace(
        vector(1) and on () (%(expr5m)s > %(sloExpr1h)s),
        "period", "5m", "", ""
      )
      or
      label_replace(
        vector(2) and on () (%(expr1h)s > %(sloExpr1h)s),
        "period", "1h", "", ""
      )
      or
      label_replace(
        vector(4) and on () (%(expr30m)s > %(sloExpr6h)s),
        "period", "30m", "", ""
      )
      or
      label_replace(
        vector(8) and on () (%(expr6h)s > %(sloExpr6h)s),
        "period", "6h", "", ""
      )
    )
  ||| % {
    expr1h: expr1h,
    expr5m: expr5m,
    expr6h: expr6h,
    expr30m: expr30m,
    sloExpr1h: strings.chomp(sloExpr1h),
    sloExpr6h: strings.chomp(sloExpr6h),
  };

local statusDescriptionPanel(legendFormat, query) =
  basic.statPanel(
    title='Status',
    panelTitle='',
    color=std.mapWithIndex(
      function(index, v)
        {
          value: index,
          color: v.color,
        },
      descriptionMappings
    ),
    query=query,
    allValues=false,
    reducerFunction='lastNotNull',
    graphMode='none',
    colorMode='background',
    justifyMode='auto',
    thresholdsMode='absolute',
    unit='none',
    orientation='vertical',
    mappings=[{
      type: 'value',
      options: objects.fromPairs(
        std.mapWithIndex(
          function(index, v)
            [index, v { index: index }],
          descriptionMappings
        )
      ),
    }],
    legendFormat=legendFormat,
  );

{
  apdexStatusQuery(selectorHash, aggregationSet, sli=null, fixedThreshold=null)::
    apdexStatusQuery(selectorHash, selectorHash.type, aggregationSet=aggregationSet, sli=sli, fixedThreshold=fixedThreshold),

  apdexStatusDescriptionPanel(name, selectorHash, aggregationSet, sli=null, fixedThreshold=null)::
    local query = apdexStatusQuery(selectorHash, selectorHash.type, aggregationSet=aggregationSet, sli=sli, fixedThreshold=fixedThreshold);
    statusDescriptionPanel(legendFormat=name + ' | Latency/Apdex', query=query),

  errorRateStatusQuery(selectorHash, aggregationSet, sli=null, fixedThreshold=null)::
    errorRateStatusQuery(selectorHash, selectorHash.type, aggregationSet=aggregationSet, sli=sli, fixedThreshold=fixedThreshold),

  errorRateStatusDescriptionPanel(name, selectorHash, aggregationSet, sli=null, fixedThreshold=null)::
    local query = errorRateStatusQuery(selectorHash, selectorHash.type, aggregationSet=aggregationSet, sli=sli, fixedThreshold=fixedThreshold);
    statusDescriptionPanel(legendFormat=name + ' | Errors', query=query),

}
