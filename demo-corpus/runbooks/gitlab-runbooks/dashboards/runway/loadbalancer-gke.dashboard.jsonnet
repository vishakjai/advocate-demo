local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local template = grafana.template;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

// GKE-specific selector configuration
local formatConfig = {
  gkeSelector: selectors.serializeHash({
    env: '$environment',
    runtime: 'gke',
    forwarding_rule_name: { re: '$loadbalancer' },
  }),
};

basic.dashboard(
  'Runway Load Balancer Metrics - GKE',
  tags=['runway', 'type:runway', 'runway-lb', 'gke'],
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=mimirHelper.mimirDatasource('runway'),
  uid='runway-loadbalancer-gke'
)
// Environment template - hardcoded values
.addTemplate(template.custom(
  'environment',
  'production,staging',
  'production',
))
// Load balancer selection template (GKE only)
.addTemplate(template.new(
  'loadbalancer',
  '$PROMETHEUS_DS',
  'label_values(runway_lb_request_count{env="$environment", runtime="gke"}, forwarding_rule_name)',
  refresh='load',
  sort=1,
  includeAll=true,
  allValues='.+',
  current='',
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
      // GKE-specific: Request rate by response code
      panel.timeSeries(
        title='Request rate by status',
        description='Rate of GKE load balancer requests grouped by HTTP status code.',
        yAxisLabel='Requests per Second',
        query=|||
          sum by(response_code) (
            rate(
              runway_lb_request_count{%(gkeSelector)s}[$__rate_interval]
            )
          )
        ||| % formatConfig,
        legendFormat='HTTP {{response_code}}',
        intervalFactor=2,
      ),

      // GKE request volume
      panel.timeSeries(
        title='Request volume by load balancer',
        description='GKE load balancer request volume by forwarding rule.',
        yAxisLabel='Requests per Second',
        query=|||
          sum by(forwarding_rule_name) (
            rate(
              runway_lb_request_count{%(gkeSelector)s}[$__rate_interval]
            )
          )
        ||| % formatConfig,
        legendFormat='{{forwarding_rule_name}}',
        intervalFactor=2,
      ),

      // GKE Backend latency (p99)
      panel.latencyTimeSeries(
        title='Backend latency (p99)',
        description='GKE load balancer backend latency 99th percentile.',
        yAxisLabel='Duration',
        query=|||
          histogram_quantile(
            0.99,
            sum by(le, forwarding_rule_name) (
              rate(runway_lb_backend_latency_milliseconds_bucket{%(gkeSelector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        format='ms',
        legendFormat='{{forwarding_rule_name}} p99',
        intervalFactor=2,
      ),

      // GKE Total latency (p99)
      panel.latencyTimeSeries(
        title='Total latency (p99)',
        description='GKE load balancer total latency 99th percentile (proxy to client).',
        yAxisLabel='Duration',
        query=|||
          histogram_quantile(
            0.99,
            sum by(le, forwarding_rule_name) (
              rate(runway_lb_total_latency_milliseconds_bucket{%(gkeSelector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        format='ms',
        legendFormat='{{forwarding_rule_name}} p99',
        intervalFactor=2,
      ),

      // GKE Backend request count
      panel.timeSeries(
        title='Backend request count',
        description='GKE load balancer backend request count (requests reaching backends).',
        yAxisLabel='Requests per Second',
        query=|||
          sum by(forwarding_rule_name) (
            rate(
              runway_lb_backend_request_count{%(gkeSelector)s}[$__rate_interval]
            )
          )
        ||| % formatConfig,
        legendFormat='{{forwarding_rule_name}} backend',
        intervalFactor=2,
      ),

      // GKE Request drop rate
      panel.timeSeries(
        title='Request drop rate',
        description='Difference between total and backend requests (requests not reaching backends).',
        yAxisLabel='Dropped Requests per Second',
        query=|||
          sum by(forwarding_rule_name) (
            rate(
              runway_lb_request_count{%(gkeSelector)s}[$__rate_interval]
            )
          )
          -
          sum by(forwarding_rule_name) (
            rate(
              runway_lb_backend_request_count{%(gkeSelector)s}[$__rate_interval]
            )
          )
        ||| % formatConfig,
        legendFormat='{{forwarding_rule_name}} dropped',
        intervalFactor=2,
      ),
    ]
  )
)
