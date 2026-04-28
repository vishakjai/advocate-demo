local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prebuiltTemplates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Secret Detection - Partner Token Verification',
  tags=['secret-detection', 'security'],
  time_from='now-6h',
  time_to='now',
  editable=true,
  uid='sd-partner-token-verify',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
)
.addTemplate(prebuiltTemplates.environment)
.addTemplate(prebuiltTemplates.stage)
.addPanels(
  layout.grid([
    basic.gaugePanel(
      'Current Error Rate',
      query='(sum(rate(validity_check_partner_api_requests_total{env="$environment", stage="$stage", status="failure"}[5m])) / sum(rate(validity_check_partner_api_requests_total{env="$environment", stage="$stage"}[5m]))) * 100',
      description='Real-time error rate percentage across all partners. Alerts trigger above 10%.',
      unit='percent',
      max=100,
      min=0,
      instant=false,
      color=[
        { color: 'green', value: 0 },
        { color: 'yellow', value: 5 },
        { color: 'red', value: 10 },
      ],
      stableId='current-error-rate',
    ),
    panel.timeSeries(
      title='API Response Time (P95)',
      description='95th percentile latency for token verification API calls to external partners (AWS, GCP, Postman). Spikes indicate partner API slowdowns.',
      query='histogram_quantile(0.95, sum(rate(validity_check_partner_api_duration_seconds_bucket{env="$environment", stage="$stage"}[5m])) by (partner, le))',
      legendFormat='{{partner}}',
      yAxisLabel='seconds',
      format='s',
      stableId='api-response-time-p95',
    ),
    basic.statPanel(
      title='Rate Limit Hits',
      panelTitle='Rate Limit Hits',
      query='sum(rate(validity_check_rate_limit_hits_total{env="$environment", stage="$stage"}[5m]))',
      description='Number of partner rate limits currently being hit. Zero is healthy.',
      unit='reqps',
      instant=false,
      color=[
        { color: 'green', value: 0 },
        { color: 'yellow', value: 0.1 },
        { color: 'red', value: 1 },
      ],
      stableId='rate-limit-hits',
    ),
  ], cols=3, rowHeight=8, startRow=0)
)
.addPanels(
  layout.grid([
    panel.timeSeries(
      title='Requests per Second by Partner',
      description='Request rate to each partner API. Use to identify traffic patterns.',
      query='sum(rate(validity_check_partner_api_requests_total{env="$environment", stage="$stage"}[5m])) by (partner)',
      legendFormat='{{partner}}',
      yAxisLabel='req/sec',
      fill=0,
      stableId='requests-per-second-by-partner',
    ),
    panel.timeSeries(
      title='Success Rate by Partner',
      description='Percentage of successful verifications per partner. Should stay above 95%.',
      query='sum(rate(validity_check_partner_api_requests_total{env="$environment", stage="$stage", status="success"}[5m])) by (partner) / sum(rate(validity_check_partner_api_requests_total{env="$environment", stage="$stage"}[5m])) by (partner) * 100',
      legendFormat='{{partner}}',
      yAxisLabel='percent',
      fill=0,
      stableId='success-rate-by-partner',
    ),
    panel.timeSeries(
      title='Errors by Type',
      description='Breakdown of failures by type: network errors, rate limits, or response parsing issues.',
      query='sum(rate(validity_check_partner_api_requests_total{env="$environment", stage="$stage", status="failure"}[5m])) by (error_type)',
      legendFormat='{{error_type}}',
      yAxisLabel='req/sec',
      fill=20,
      stack=true,
      stableId='errors-by-type',
    ),
  ], cols=3, rowHeight=8, startRow=8)
)
.addPanels(
  layout.grid([
    panel.timeSeries(
      title='Network Errors by Partner',
      description='Detailed network error types (Timeout, ConnectionRefused, HTTPError) to diagnose connectivity issues.',
      query='sum(rate(validity_check_network_errors_total{env="$environment", stage="$stage"}[5m])) by (partner, error_class)',
      legendFormat='{{partner}} - {{error_class}}',
      yAxisLabel='req/sec',
      fill=0,
      stableId='network-errors-by-partner',
    ),
    panel.timeSeries(
      title='Rate Limits by Partner',
      description="Shows which partner rate limit you're hitting so you can adjust.",
      query='sum(rate(validity_check_rate_limit_hits_total{env="$environment", stage="$stage"}[5m])) by (limit_type)',
      legendFormat='{{limit_type}}',
      yAxisLabel='req/sec',
      fill=0,
      stableId='rate-limits-by-partner',
    ),
  ], cols=2, rowHeight=8, startRow=16)
)
.trailer()
