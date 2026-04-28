// Operational dashboard for the feature-flag service (Flipt on Runway).
//
// Covers: flag evaluation patterns, evaluation latency, git sync health,
// Go runtime metrics (goroutines, memory, processor limits).
//
// All metrics flow through OTLP and use service_name="feature-flag".
//
// Available metrics (confirmed via Explore):
//   flipt_evaluations_requests_total       (counter)
//   flipt_evaluations_results_total        (counter, labels TBD)
//   flipt_evaluations_latency_milliseconds (histogram)
//   flipt_server_errors_total              (counter)
//   flipt_git_views_total                  (counter)
//   flipt_git_poll_errors_total            (counter)
//   flipt_git_view_latency_milliseconds    (histogram)
//   go_goroutine_count                     (gauge)
//   go_memory_used_bytes                   (gauge)
//   go_memory_allocated_bytes_total        (counter)
//   go_memory_gc_goal_bytes                (gauge)
//   go_processor_limit                     (gauge)
//   go_config_gogc_percent                 (gauge)
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local row = grafana.row;
local template = grafana.template;

local datasource = 'mimir-runway';
local sel = 'service_name="feature-flag"';

// ---------------------------------------------------------------------------
// Row 1: Flag evaluation patterns
// ---------------------------------------------------------------------------

local evaluationRatePanel =
  panel.timeSeries(
    title='Flag Evaluation Rate',
    description='Total flag evaluation requests per second.',
    query='sum(rate(flipt_evaluations_requests_total{%s}[$__rate_interval]))' % sel,
    legendFormat='Evaluations/s',
    format='reqps',
    yAxisLabel='req/s',
    min=0,
  );

local serverErrorsPanel =
  panel.timeSeries(
    title='Server Errors/s',
    description='Rate of server errors. Non-zero means requests are failing.',
    query='sum(rate(flipt_server_errors_total{%s}[$__rate_interval])) or vector(0)' % sel,
    legendFormat='Errors/s',
    format='reqps',
    yAxisLabel='errors/s',
    min=0,
    thresholdSteps=[
      { color: 'green', value: 0 },
      { color: 'red', value: 0.01 },
    ],
  );

// ---------------------------------------------------------------------------
// Row 2: Evaluation latency (server-side, from OTLP histogram)
// ---------------------------------------------------------------------------

local evalLatencyPanel =
  panel.multiTimeSeries(
    title='Evaluation Latency',
    description='Server-side flag evaluation latency (p50, p95, p99) from the OTLP histogram.',
    queries=[
      {
        query: 'histogram_quantile(0.50, sum(rate(flipt_evaluations_latency_milliseconds_bucket{%s}[$__rate_interval])) by (le))' % sel,
        legendFormat: 'p50',
      },
      {
        query: 'histogram_quantile(0.95, sum(rate(flipt_evaluations_latency_milliseconds_bucket{%s}[$__rate_interval])) by (le))' % sel,
        legendFormat: 'p95',
      },
      {
        query: 'histogram_quantile(0.99, sum(rate(flipt_evaluations_latency_milliseconds_bucket{%s}[$__rate_interval])) by (le))' % sel,
        legendFormat: 'p99',
      },
    ],
    yAxisLabel='Latency',
    format='ms',
    min=0,
  );

local evalThroughputPanel =
  panel.timeSeries(
    title='Evaluation Throughput',
    description='Completed evaluations per second (from histogram count).',
    query='sum(rate(flipt_evaluations_latency_milliseconds_count{%s}[$__rate_interval]))' % sel,
    legendFormat='evals/s',
    format='reqps',
    yAxisLabel='evals/s',
    min=0,
  );

// ---------------------------------------------------------------------------
// Row 3: Git sync health
// ---------------------------------------------------------------------------

local gitViewsPanel =
  panel.timeSeries(
    title='Git Views Rate',
    description='Rate of git storage views (flag lookups from the git backend).',
    query='sum(rate(flipt_git_views_total{%s}[$__rate_interval]))' % sel,
    legendFormat='Views/s',
    format='reqps',
    yAxisLabel='views/s',
    min=0,
  );

local gitPollErrorsPanel =
  panel.timeSeries(
    title='Git Poll Errors',
    description='Rate of git poll errors. Non-zero means flag sync from the repository is failing.',
    query='sum(rate(flipt_git_poll_errors_total{%s}[$__rate_interval])) or vector(0)' % sel,
    legendFormat='Errors/s',
    format='reqps',
    yAxisLabel='errors/s',
    min=0,
    thresholdSteps=[
      { color: 'green', value: 0 },
      { color: 'red', value: 0.01 },
    ],
  );

local gitViewLatencyPanel =
  panel.multiTimeSeries(
    title='Git View Latency',
    description='Server-side git view latency (p50, p95, p99).',
    queries=[
      {
        query: 'histogram_quantile(0.50, sum(rate(flipt_git_view_latency_milliseconds_bucket{%s}[$__rate_interval])) by (le))' % sel,
        legendFormat: 'p50',
      },
      {
        query: 'histogram_quantile(0.95, sum(rate(flipt_git_view_latency_milliseconds_bucket{%s}[$__rate_interval])) by (le))' % sel,
        legendFormat: 'p95',
      },
      {
        query: 'histogram_quantile(0.99, sum(rate(flipt_git_view_latency_milliseconds_bucket{%s}[$__rate_interval])) by (le))' % sel,
        legendFormat: 'p99',
      },
    ],
    yAxisLabel='Latency',
    format='ms',
    min=0,
  );

// ---------------------------------------------------------------------------
// Row 4: Go runtime (all via OTLP, service_name selector)
// ---------------------------------------------------------------------------

local goroutinesPanel =
  panel.timeSeries(
    title='Goroutines',
    description='Number of active goroutines. A sustained increase may indicate a goroutine leak.',
    query='sum by (host_name) (go_goroutine_count{%s})' % sel,
    legendFormat='{{host_name}}',
    format='short',
    yAxisLabel='Goroutines',
    min=0,
  );

local memoryUsedPanel =
  panel.timeSeries(
    title='Memory Used',
    description='Go runtime memory in use (go_memory_used_bytes).',
    query='sum by (host_name) (go_memory_used_bytes{%s})' % sel,
    legendFormat='{{host_name}}',
    format='bytes',
    yAxisLabel='Memory',
    min=0,
  );

local memoryAllocRatePanel =
  panel.timeSeries(
    title='Memory Allocation Rate',
    description='Rate of memory allocation. Sustained high allocation drives GC pressure.',
    query='sum by (host_name) (rate(go_memory_allocated_bytes_total{%s}[$__rate_interval]))' % sel,
    legendFormat='{{host_name}}',
    format='Bps',
    yAxisLabel='bytes/s',
    min=0,
  );

local gcGoalPanel =
  panel.timeSeries(
    title='GC Goal vs Used',
    description='GC heap goal compared to actual used memory. GC triggers when used approaches the goal.',
    query='sum by (host_name) (go_memory_gc_goal_bytes{%s})' % sel,
    legendFormat='{{host_name}}',
    format='bytes',
    yAxisLabel='Memory',
    min=0,
  );

// ---------------------------------------------------------------------------
// Dashboard assembly
// ---------------------------------------------------------------------------

basic.dashboard(
  'Feature Flags: Operational',
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
  row.new(title='Flag Evaluation Patterns'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanels(layout.grid([evaluationRatePanel, serverErrorsPanel], cols=2, rowHeight=8, startRow=100))
.addPanel(
  row.new(title='Evaluation Latency'),
  gridPos={ x: 0, y: 200, w: 24, h: 1 },
)
.addPanels(layout.grid([evalLatencyPanel, evalThroughputPanel], cols=2, rowHeight=8, startRow=300))
.addPanel(
  row.new(title='Git Sync Health'),
  gridPos={ x: 0, y: 400, w: 24, h: 1 },
)
.addPanels(layout.grid([gitViewsPanel, gitPollErrorsPanel, gitViewLatencyPanel], cols=3, rowHeight=8, startRow=500))
.addPanel(
  row.new(title='Go Runtime'),
  gridPos={ x: 0, y: 600, w: 24, h: 1 },
)
.addPanels(layout.grid([goroutinesPanel, memoryUsedPanel, memoryAllocRatePanel, gcGoalPanel], cols=2, rowHeight=8, startRow=700))
.trailer()
