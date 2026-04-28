// Primary health dashboard for the feature-flag service (Flipt on Runway).
//
// Covers: availability, request rate, latency, error rate, resource utilization.
//
// Metric sources and their label schemes:
//   kube-state-metrics / cAdvisor:  namespace="feature-flag"
//   Flipt OTLP (via collector):     service_name="feature-flag"
//   Runway LB (EKS ALB gauges):     env="$environment", load_balancer=~".*featuref.*"
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local row = grafana.row;
local template = grafana.template;

local datasource = 'mimir-runway';
local namespace = 'feature-flag';

// Label selectors by metric source.
//   kube-state-metrics / cAdvisor → namespace label
//   Flipt OTLP (via collector)    → service_name label (from OTEL_SERVICE_NAME)
//   Runway LB (EKS ALB gauges)    → env + load_balancer labels
local kubeSel = 'namespace="%s"' % namespace;
local fliptSel = 'service_name="%s"' % namespace;
local lbSel = 'env="$environment", load_balancer=~".*featuref.*"';

// ---------------------------------------------------------------------------
// Row 1: Service availability
// ---------------------------------------------------------------------------

local podReplicasPanel =
  panel.multiTimeSeries(
    title='Pod Replicas',
    description='Desired vs available pod replicas. A gap indicates degraded availability.',
    queries=[
      { query: 'kube_deployment_spec_replicas{%s}' % kubeSel, legendFormat: 'Desired' },
      { query: 'kube_deployment_status_replicas_available{%s}' % kubeSel, legendFormat: 'Available' },
    ],
    yAxisLabel='Pods',
    format='short',
    min=0,
  );

local podRestartsPanel =
  panel.timeSeries(
    title='Pod Restarts',
    description='Container restart count. Increases indicate OOM kills or liveness probe failures.',
    query='sum(increase(kube_pod_container_status_restarts_total{%s}[$__rate_interval]))' % kubeSel,
    legendFormat='Restarts',
    format='short',
    yAxisLabel='Restarts',
    min=0,
    thresholdSteps=[
      { color: 'green', value: 0 },
      { color: 'red', value: 1 },
    ],
  );

// ---------------------------------------------------------------------------
// Row 2: Request rate and errors
// ---------------------------------------------------------------------------

local requestRatePanel =
  panel.timeSeries(
    title='Request Rate',
    description='Total flag evaluation requests per second across all pods.',
    query='sum(rate(flipt_evaluations_requests_total{%s}[$__rate_interval]))' % fliptSel,
    legendFormat='Evaluations/s',
    format='reqps',
    yAxisLabel='req/s',
    min=0,
  );

local errorRatePanel =
  panel.timeSeries(
    title='Server Error Rate',
    description='Proportion of requests returning a server error. Alert fires at 1%.',
    query=|||
      (sum(rate(flipt_server_errors_total{%(sel)s}[$__rate_interval])) or vector(0))
      /
      (sum(rate(flipt_evaluations_requests_total{%(sel)s}[$__rate_interval])) > 0)
    ||| % { sel: fliptSel },
    legendFormat='Error rate',
    format='percentunit',
    yAxisLabel='Error rate',
    min=0,
    thresholdSteps=[
      { color: 'green', value: 0 },
      { color: 'red', value: 0.01 },
    ],
  );

// ---------------------------------------------------------------------------
// Row 3: Latency (Runway load balancer — EKS ALB gauge metrics)
// ---------------------------------------------------------------------------

local lbLatencyAvgPanel =
  panel.timeSeries(
    title='LB Latency (avg)',
    description='Average backend latency as reported by the Runway EKS ALB.',
    query='runway_lb_backend_latency_milliseconds{%s, statistic="average"}' % lbSel,
    legendFormat='avg',
    format='ms',
    yAxisLabel='Latency',
    min=0,
  );

local lbLatencyStatsPanel =
  panel.multiTimeSeries(
    title='LB Latency (min / avg / max)',
    description='Backend latency statistics from the Runway EKS ALB.',
    queries=[
      { query: 'runway_lb_backend_latency_milliseconds{%s, statistic="minimum"}' % lbSel, legendFormat: 'min' },
      { query: 'runway_lb_backend_latency_milliseconds{%s, statistic="average"}' % lbSel, legendFormat: 'avg' },
      { query: 'runway_lb_backend_latency_milliseconds{%s, statistic="maximum"}' % lbSel, legendFormat: 'max' },
    ],
    yAxisLabel='Latency',
    format='ms',
    min=0,
  );

// ---------------------------------------------------------------------------
// Row 4: LB traffic
// ---------------------------------------------------------------------------

local lbRequestRatePanel =
  panel.timeSeries(
    title='LB Request Rate',
    description='Requests per second through the Runway load balancer.',
    query='sum(rate(runway_lb_request_count{%s}[$__rate_interval]))' % lbSel,
    legendFormat='Requests/s',
    format='reqps',
    yAxisLabel='req/s',
    min=0,
  );

local lbResponseCodesPanel =
  panel.timeSeries(
    title='LB Response Codes',
    description='Load balancer response codes grouped by status class.',
    query='sum by (response_code_class) (rate(runway_lb_request_count{%s}[$__rate_interval]))' % lbSel,
    legendFormat='HTTP {{response_code_class}}',
    format='reqps',
    yAxisLabel='req/s',
    min=0,
  );

// ---------------------------------------------------------------------------
// Row 5: Resource utilization
// ---------------------------------------------------------------------------

local cpuUsagePanel =
  panel.timeSeries(
    title='CPU Usage',
    description='CPU usage per pod. Request is 250m, limit is 1000m.',
    query='sum by (pod) (rate(container_cpu_usage_seconds_total{%s}[$__rate_interval]))' % kubeSel,
    legendFormat='{{pod}}',
    format='short',
    yAxisLabel='CPU cores',
    min=0,
  );

local memoryUsagePanel =
  panel.timeSeries(
    title='Memory Usage (RSS)',
    description='Resident memory per pod. Limit is 512Mi; alert fires at 80%.',
    query='sum by (pod) (container_memory_rss{%s})' % kubeSel,
    legendFormat='{{pod}}',
    format='bytes',
    yAxisLabel='Memory',
    min=0,
    thresholdSteps=[
      { color: 'green', value: 0 },
      { color: 'orange', value: 0.8 * 512 * 1024 * 1024 },
      { color: 'red', value: 512 * 1024 * 1024 },
    ],
  );

// ---------------------------------------------------------------------------
// Dashboard assembly
// ---------------------------------------------------------------------------

basic.dashboard(
  'Feature Flags: Service Health',
  tags=['feature-flags', 'runway', 'flipt', 'managed'],
  time_from='now-3h',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=datasource,
)
.addTemplate(template.custom(
  'environment',
  'production,staging',
  'production',
))
.addPanel(
  row.new(title='Availability'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanels(layout.grid([podReplicasPanel, podRestartsPanel], cols=2, rowHeight=8, startRow=100))
.addPanel(
  row.new(title='Request Rate & Errors'),
  gridPos={ x: 0, y: 200, w: 24, h: 1 },
)
.addPanels(layout.grid([requestRatePanel, errorRatePanel], cols=2, rowHeight=8, startRow=300))
.addPanel(
  row.new(title='Latency (Runway LB)'),
  gridPos={ x: 0, y: 400, w: 24, h: 1 },
)
.addPanels(layout.grid([lbLatencyAvgPanel, lbLatencyStatsPanel], cols=2, rowHeight=8, startRow=500))
.addPanel(
  row.new(title='Load Balancer Traffic'),
  gridPos={ x: 0, y: 600, w: 24, h: 1 },
)
.addPanels(layout.grid([lbRequestRatePanel, lbResponseCodesPanel], cols=2, rowHeight=8, startRow=700))
.addPanel(
  row.new(title='Resource Utilization'),
  gridPos={ x: 0, y: 800, w: 24, h: 1 },
)
.addPanels(layout.grid([cpuUsagePanel, memoryUsagePanel], cols=2, rowHeight=8, startRow=900))
.trailer()
