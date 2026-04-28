local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

local tokenUsage(tokenUsageType) =
  local formatConfig = { tokenUsageType: tokenUsageType };

  {
    title: '%(tokenUsageType)s token usage' % formatConfig,
    severity: 's3',
    horizontallyScalable: false,
    appliesTo: ['ai-gateway'],
    burnRatePeriod: '1m',
    runbook: 'ai-gateway/rate_limits/',
    description: |||
      %(tokenUsageType)s token usage per engine/model. LLM providers will reject requests as long as the rate
      limit is exceeded, which may result in user-facing errors depending on the client's retry/back-off logic
    ||| % formatConfig,
    grafana_dashboard_uid: '%(tokenUsageType)s_token_usage' % formatConfig,
    resourceLabels: ['model_engine', 'model_name'],
    query: |||
      sum by (%(aggregationLabels)s) (
        increase(inference_%(tokenUsageType)s_tokens_total{%(selector)s}[%(rangeInterval)s])
      )
      /
      min by (%(aggregationLabels)s)(min_over_time(model_max_%(tokenUsageType)s_tokens{%(selector)s}[%(rangeInterval)s]))
    |||,
    queryFormatConfig: formatConfig,
    slos: {
      soft: 0.85,
      hard: 0.90,
      alertTriggerDuration: '15m',
    },
  };

{
  llm_input_token_usage: resourceSaturationPoint(tokenUsage('input')),
  llm_output_token_usage: resourceSaturationPoint(tokenUsage('output')),
  llm_total_token_usage: resourceSaturationPoint(tokenUsage('total')),
}
