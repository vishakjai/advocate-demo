local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local datasource = import 'gitlab-dashboards/datasource.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local row = grafana.row;

local type = 'topology-grpc';
local service = metricsCatalog.getService(type);
local formatConfig = {
  selector: selectors.serializeHash({ env: '$environment', environment: '$environment', type: type, job: 'topology-service' }),
  selectorFailures: selectors.serializeHash({ env: '$environment', environment: '$environment', type: type, job: 'topology-service', status: 'failure' }),
  selectorSuccess: selectors.serializeHash({ env: '$environment', environment: '$environment', type: type, job: 'topology-service', status: 'success' }),
};

basic.dashboard(
  'RBAC Authentication Monitoring',
  tags=['type:%s' % type, 'detail'],
  includeEnvironmentTemplate=true,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=datasource.defaultDatasourceForService(service),
)

// -------------------------------------------------------------------------
// Row 1: Authentication Overview
// -------------------------------------------------------------------------
.addPanel(
  row.new(title='Authentication Overview'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        stableId='auth-request-rate',
        title='Auth Request Rate by Status',
        query=|||
          sum by (status) (
            rate(auth_requests_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{status}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-success-ratio',
        title='Auth Success Ratio',
        query=|||
          sum(rate(auth_requests_total{%(selectorSuccess)s}[$__rate_interval]))
          /
          sum(rate(auth_requests_total{%(selector)s}[$__rate_interval]))
        ||| % formatConfig,
        legendFormat='Success Ratio',
        format='percentunit',
        yAxisLabel='Ratio',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-request-rate-by-user-type',
        title='Auth Request Rate by User Type (OU)',
        query=|||
          sum by (ou) (
            rate(auth_requests_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='ou={{ou}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-failure-rate-by-reason',
        title='Auth Failure Rate by Reason',
        query=|||
          sum by (reason) (
            rate(auth_requests_total{%(selectorFailures)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{reason}}',
        format='ops',
        yAxisLabel='Failures per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-request-rate-by-method',
        title='Auth Request Rate by gRPC Method',
        query=|||
          sum by (rpc_service, rpc_method) (
            rate(auth_requests_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-request-rate-by-region',
        title='Auth Request Rate by Region',
        query=|||
          sum by (region) (
            rate(auth_requests_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='ops',
        yAxisLabel='Requests per Second',
        interval='1m',
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=1,
  )
)

// -------------------------------------------------------------------------
// Row 2: Security Monitoring
// -------------------------------------------------------------------------
.addPanel(
  row.new(title='Security Monitoring'),
  gridPos={ x: 0, y: 1000, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        stableId='policy-violation-rate',
        title='Policy Violation Rate',
        query=|||
          sum by (reason) (
            rate(policy_failures_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{reason}}',
        format='ops',
        yAxisLabel='Violations per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-failures-by-reason',
        title='Auth Failures by Reason',
        query=|||
          sum by (reason) (
            rate(auth_requests_total{%(selectorFailures)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{reason}}',
        format='ops',
        yAxisLabel='Failures per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-failures-by-method',
        title='Auth Failures by gRPC Method',
        query=|||
          sum by (rpc_service, rpc_method) (
            rate(auth_requests_total{%(selectorFailures)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}}',
        format='ops',
        yAxisLabel='Failures per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='policy-failures-by-method',
        title='Policy Failures by gRPC Method',
        query=|||
          sum by (rpc_service, rpc_method, reason) (
            rate(policy_failures_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{rpc_service}}/{{rpc_method}} - {{reason}}',
        format='ops',
        yAxisLabel='Failures per Second',
        interval='1m',
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=1001,
  )
)

// -------------------------------------------------------------------------
// Row 3: Performance
// -------------------------------------------------------------------------
.addPanel(
  row.new(title='Authentication Performance'),
  gridPos={ x: 0, y: 2000, w: 24, h: 1 }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        stableId='auth-duration-p99',
        title='Auth Duration P99',
        query=|||
          histogram_quantile(0.99,
            sum by (le, rpc_method, rpc_service) (
              rate(auth_request_duration_seconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='p99 {{rpc_service}}/{{rpc_method}}',
        format='s',
        yAxisLabel='Duration',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-duration-p95',
        title='Auth Duration P95',
        query=|||
          histogram_quantile(0.95,
            sum by (le, rpc_method, rpc_service) (
              rate(auth_request_duration_seconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='p95 {{rpc_service}}/{{rpc_method}}',
        format='s',
        yAxisLabel='Duration',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-duration-p50',
        title='Auth Duration P50 (Median)',
        query=|||
          histogram_quantile(0.50,
            sum by (le, rpc_method, rpc_service) (
              rate(auth_request_duration_seconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='p50 {{rpc_service}}/{{rpc_method}}',
        format='s',
        yAxisLabel='Duration',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='auth-duration-avg',
        title='Auth Duration Average',
        query=|||
          sum by (rpc_method, rpc_service) (
            rate(auth_request_duration_seconds_sum{%(selector)s}[$__rate_interval])
          )
          /
          sum by (rpc_method, rpc_service) (
            rate(auth_request_duration_seconds_count{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='avg {{rpc_service}}/{{rpc_method}}',
        format='s',
        yAxisLabel='Duration',
        interval='1m',
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=2001,
  )
)

.trailer()
