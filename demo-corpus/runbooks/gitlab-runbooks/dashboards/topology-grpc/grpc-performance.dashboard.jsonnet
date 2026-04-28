local datasource = import 'gitlab-dashboards/datasource.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local type = 'topology-grpc';
local service = metricsCatalog.getService(type);
local formatConfig = {
  selector: selectors.serializeHash({ env: '$environment', environment: '$environment', type: type, job: 'topology-service' }),
};

basic.dashboard(
  'gRPC Performance',
  tags=['type:%s' % type, 'detail'],
  includeEnvironmentTemplate=true,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=datasource.defaultDatasourceForService(service),
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        stableId='grpc-request-rate-by-method',
        title='gRPC Request Rate by Method',
        query=|||
          sum by (rpc_service, rpc_method, region) (
            rate(rpc_server_duration_milliseconds_count{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}} - {{region}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='grpc-p95-latency-by-method',
        title='gRPC P95 Latency by Method',
        query=|||
          histogram_quantile(0.95,
            sum by (le, rpc_service, rpc_method, region) (
              rate(rpc_server_duration_milliseconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}} - {{region}}',
        format='ms',
        yAxisLabel='Latency (P95)',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='grpc-p99-latency-by-method',
        title='gRPC P99 Latency by Method',
        query=|||
          histogram_quantile(0.99,
            sum by (le, rpc_service, rpc_method, region) (
              rate(rpc_server_duration_milliseconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}} - {{region}}',
        format='ms',
        yAxisLabel='Latency (P99)',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='grpc-p50-latency-by-method',
        title='gRPC P50 Latency by Method',
        query=|||
          histogram_quantile(0.50,
            sum by (le, rpc_service, rpc_method, region) (
              rate(rpc_server_duration_milliseconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}} - {{region}}',
        format='ms',
        yAxisLabel='Latency (P50)',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='grpc-avg-request-size',
        title='Average Request Size by Method',
        query=|||
          sum by (rpc_service, rpc_method, region) (
            rate(rpc_server_request_size_bytes_sum{%(selector)s}[$__rate_interval])
          )
          /
          sum by (rpc_service, rpc_method, region) (
            rate(rpc_server_request_size_bytes_count{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}} - {{region}}',
        format='bytes',
        yAxisLabel='Request Size',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='grpc-avg-response-size',
        title='Average Response Size by Method',
        query=|||
          sum by (rpc_service, rpc_method, region) (
            rate(rpc_server_response_size_bytes_sum{%(selector)s}[$__rate_interval])
          )
          /
          sum by (rpc_service, rpc_method, region) (
            rate(rpc_server_response_size_bytes_count{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}} - {{region}}',
        format='bytes',
        yAxisLabel='Response Size',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='grpc-request-rate-by-region',
        title='Total Request Rate by Region',
        query=|||
          sum by (region) (
            rate(rpc_server_duration_milliseconds_count{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='grpc-error-rate-by-method',
        title='gRPC Error Rate by Method',
        query=|||
          sum by (rpc_service, rpc_method, region) (
            rate(rpc_server_duration_milliseconds_count{%(selector)s,grpc_status_code!="OK"}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}} - {{region}}',
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
