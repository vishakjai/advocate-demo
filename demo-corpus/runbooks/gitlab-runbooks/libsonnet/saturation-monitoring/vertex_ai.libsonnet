local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;
local gcpQuotaLimit = import 'saturation-monitoring/gcp_quota_limit.libsonnet';


local gcpQuotaLimitVertexAiTokens(tokenUsageType) =
  local formatConfig = { tokenUsageType: tokenUsageType };

  gcpQuotaLimit.gcp_quota_limit {
    title: 'GCP %(tokenUsageType)s tokens quota utilization' % formatConfig,
    severity: 's4',
    appliesTo: ['ai-gateway'],
    grafana_dashboard_uid: 'sat_vertex_ai_%(tokenUsageType)s_tokens' % formatConfig,
    // TODO: remove this location label, it is used in Thanos environments where
    // the `region` label is overridden as an external label advertised by prometheus
    // https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/3398
    resourceLabels: ['base_model', 'region', 'location'],
    description: |||
      GCP Quota utilization / limit ratio for %(tokenUsageType)s tokens per minute per model and region.

      Saturation on the quota may cause problems with the requests.

      To fix, we can request a quota increase for the specific resource to the GCP support team.
    ||| % formatConfig,
    query: |||
      (
        sum without (method) ({__name__=~"stackdriver_aiplatform_googleapis_com_location_aiplatform_googleapis_com_quota_.*online_prediction_%(tokenUsageType)s_tokens_per_minute_per_base_model_usage", %(selector)s})
      /
        {__name__=~"stackdriver_aiplatform_googleapis_com_location_aiplatform_googleapis_com_quota_.*online_prediction_%(tokenUsageType)s_tokens_per_minute_per_base_model_limit", %(selector)s}
      ) > 0
    |||,
    queryFormatConfig: formatConfig,
  };

{
  gcp_quota_limit_vertex_ai: resourceSaturationPoint(gcpQuotaLimit.gcp_quota_limit {
    severity: 's4',
    appliesTo: ['ai-gateway'],
    grafana_dashboard_uid: 'sat_gcp_quota_limit_vertex_ai',
    // TODO: remove this location label, it is used in Thanos environments where
    // the `region` label is overridden as an external label advertised by prometheus
    // https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/3398
    resourceLabels: ['base_model', 'region', 'location'],
    description: |||
      GCP Quota utilization / limit ratio for all vertex AI models

      Saturation on the quota may cause problems with the requests.

      To fix, we can request a quota increase for the specific resource to the GCP support team.
    |||,
    query: |||
      (
        sum without (method) (stackdriver_aiplatform_googleapis_com_location_aiplatform_googleapis_com_quota_online_prediction_requests_per_base_model_usage{%(selector)s})
      /
        stackdriver_aiplatform_googleapis_com_location_aiplatform_googleapis_com_quota_online_prediction_requests_per_base_model_limit{%(selector)s}
      ) > 0
    |||,
  }),

  gcp_quota_limit_vertex_ai_input_tokens: resourceSaturationPoint(gcpQuotaLimitVertexAiTokens('input')),
  gcp_quota_limit_vertex_ai_output_tokens: resourceSaturationPoint(gcpQuotaLimitVertexAiTokens('output')),
}
