local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local template = grafana.template;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

// Cross-cloud selector configuration
local formatConfig = {
  // Base selector for all runway load balancer metrics
  baseSelector: selectors.serializeHash({
    env: '$environment',
    runtime: { re: '$runtime' },
  }),
};

basic.dashboard(
  'Runway Load Balancer Metrics - Main',
  tags=['runway', 'type:runway', 'runway-lb'],
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=mimirHelper.mimirDatasource('runway'),
  uid='runway-loadbalancer-main'
)
// Environment template - hardcoded values
.addTemplate(template.custom(
  'environment',
  'production,staging',
  'production',
))
// Runtime selection template
.addTemplate(template.new(
  'runtime',
  '$PROMETHEUS_DS',
  'label_values(runway_lb_request_count{env="$environment"}, runtime)',
  refresh='load',
  sort=1,
  includeAll=true,
  allValues='eks|gke|cloudrun',
  current='All'
))
// Dashboard links dropdown to all Runway dashboards
.addLink(grafana.link.dashboards(
  title='Runway',
  tags=['runway', 'type:runway'],
  asDropdown=true,
  includeVars=true,
))
// Runway deployment annotations
.addAnnotation(
  grafana.annotation.datasource(
    'runway-deploy',
    '-- Grafana --',
    iconColor='#fda324',
    tags=['platform:runway', 'env:${environment}'],
    builtIn=1,
  ),
)
.addPanels(
  layout.grid(
    [
      // ===== COMBINED METRICS (TOP) =====
      // Request rate by runtime comparison
      panel.timeSeries(
        title='Request Rate by Runtime (Comparison)',
        description='Request rate for each runtime side-by-side.',
        yAxisLabel='Requests per Second',
        query=|||
          sum by(runtime) (
            rate(
              runway_lb_request_count{env="$environment", runtime=~"eks|gke|cloudrun"}[$__rate_interval]
            )
          )
        |||,
        legendFormat='{{runtime}}',
        intervalFactor=2,
      ),

      // Total request rate across all runtimes
      panel.timeSeries(
        title='Total Request Rate (All Runtimes)',
        description='Combined request rate across EKS, GKE, and CloudRun.',
        yAxisLabel='Requests per Second',
        query=|||
          sum(
            rate(
              runway_lb_request_count{env="$environment"}[$__rate_interval]
            )
          )
        |||,
        legendFormat='Total requests',
        intervalFactor=2,
      ),

      // P99 latency comparison across runtimes
      panel.latencyTimeSeries(
        title='Backend Latency P99 (All Runtimes)',
        description='Compare backend latency p99 across EKS, GKE, and CloudRun.',
        yAxisLabel='Duration',
        query=|||
          histogram_quantile(
            0.99,
            sum by(le, runtime) (
              rate(runway_lb_backend_latency_milliseconds_bucket{env="$environment", runtime=~"eks|gke|cloudrun"}[$__rate_interval])
            )
          )
        |||,
        format='ms',
        legendFormat='{{runtime}} p99',
        intervalFactor=2,
      ),

      // Total latency comparison across runtimes
      panel.latencyTimeSeries(
        title='Total Latency P99 (All Runtimes)',
        description='Compare total latency p99 across GKE and CloudRun.',
        yAxisLabel='Duration',
        query=|||
          histogram_quantile(
            0.99,
            sum by(le, runtime) (
              rate(runway_lb_total_latency_milliseconds_bucket{env="$environment", runtime=~"gke|cloudrun"}[$__rate_interval])
            )
          )
        |||,
        format='ms',
        legendFormat='{{runtime}} p99',
        intervalFactor=2,
      ),

      // Backend request count comparison
      panel.timeSeries(
        title='Backend Request Count (All Runtimes)',
        description='Compare requests reaching backends across all runtimes.',
        yAxisLabel='Requests per Second',
        query=|||
          sum by(runtime) (
            rate(
              runway_lb_backend_request_count{env="$environment", runtime=~"eks|gke|cloudrun"}[$__rate_interval]
            )
          )
        |||,
        legendFormat='{{runtime}} backend',
        intervalFactor=2,
      ),

      // Request drop rate by runtime
      panel.timeSeries(
        title='Request Drop Rate by Runtime',
        description='Difference between total and backend requests (requests not reaching backends).',
        yAxisLabel='Dropped Requests per Second',
        query=|||
          sum by(runtime) (
            rate(
              runway_lb_request_count{env="$environment", runtime=~"eks|gke|cloudrun"}[$__rate_interval]
            )
          )
          -
          sum by(runtime) (
            rate(
              runway_lb_backend_request_count{env="$environment", runtime=~"eks|gke|cloudrun"}[$__rate_interval]
            )
          )
        |||,
        legendFormat='{{runtime}} dropped',
        intervalFactor=2,
      ),
    ]
  )
)
