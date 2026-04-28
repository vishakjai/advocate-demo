local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local type = 'topology-rest';
local formatConfig = {
  selector: selectors.serializeHash({ env: '$environment', environment: '$environment', type: type, job: 'topology-service' }),
};

basic.dashboard(
  'HTTP Performance',
  tags=['type:%s' % type, 'detail'],
  includeEnvironmentTemplate=true,
  includeStandardEnvironmentAnnotations=false,
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        stableId='http-request-rate-by-status',
        title='HTTP Request Rate by Status Code',
        query=|||
          sum by (code, region) (
            rate(topology_service_http_requests_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{code}} - {{region}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-p95-latency',
        title='HTTP P95 Latency',
        query=|||
          histogram_quantile(0.95,
            sum by (le, region) (
              rate(topology_service_http_request_duration_seconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='s',
        yAxisLabel='Latency (P95)',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-p99-latency',
        title='HTTP P99 Latency',
        query=|||
          histogram_quantile(0.99,
            sum by (le, region) (
              rate(topology_service_http_request_duration_seconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='s',
        yAxisLabel='Latency (P99)',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-p50-latency',
        title='HTTP P50 Latency',
        query=|||
          histogram_quantile(0.50,
            sum by (le, region) (
              rate(topology_service_http_request_duration_seconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='s',
        yAxisLabel='Latency (P50)',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-error-rate-4xx-5xx',
        title='Error Rate - 4xx vs 5xx',
        query=|||
          sum by (region) (
            rate(topology_service_http_requests_total{%(selector)s,code=~"4.."}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='4xx - {{region}}',
        format='ops',
        yAxisLabel='Errors per Second',
        interval='1m',
      )
      .addTarget(
        promQuery.target(
          |||
            sum by (region) (
              rate(topology_service_http_requests_total{%(selector)s,code=~"5.."}[$__rate_interval])
            )
          ||| % formatConfig,
          legendFormat='5xx - {{region}}'
        )
      ),
      panel.timeSeries(
        stableId='http-in-flight-requests',
        title='In-Flight Requests',
        query=|||
          topology_service_http_in_flight_requests{%(selector)s}
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='short',
        yAxisLabel='Active Requests',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-request-rate-by-endpoint',
        title='Request Rate by Endpoint (Top 10)',
        query=|||
          topk(10,
            sum by (route, method, region) (
              rate(topology_service_http_requests_total{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{method}} {{route}} - {{region}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-ttfb-p95',
        title='Time to First Byte (TTFB) P95',
        query=|||
          histogram_quantile(0.95,
            sum by (le, region) (
              rate(topology_service_http_time_to_write_header_seconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='s',
        yAxisLabel='TTFB (P95)',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-avg-request-size',
        title='Average Request Size',
        query=|||
          sum by (region) (
            rate(topology_service_http_request_size_bytes_sum{%(selector)s}[$__rate_interval])
          )
          /
          sum by (region) (
            rate(topology_service_http_request_size_bytes_count{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='bytes',
        yAxisLabel='Request Size',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-avg-response-size',
        title='Average Response Size',
        query=|||
          sum by (region) (
            rate(topology_service_http_response_size_bytes_sum{%(selector)s}[$__rate_interval])
          )
          /
          sum by (region) (
            rate(topology_service_http_response_size_bytes_count{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='bytes',
        yAxisLabel='Response Size',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-request-rate-by-region',
        title='Total Request Rate by Region',
        query=|||
          sum by (region) (
            rate(topology_service_http_requests_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='http-error-rate-by-endpoint',
        title='Error Rate by Endpoint (5xx)',
        query=|||
          topk(10,
            sum by (route, method, region) (
              rate(topology_service_http_requests_total{%(selector)s,code=~"5.."}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{method}} {{route}} - {{region}}',
        format='ops',
        yAxisLabel='Errors per Second',
        interval='1m',
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=0,
  )
)
.trailer()
