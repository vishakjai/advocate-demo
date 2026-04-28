local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local template = grafana.template;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

// AWS-specific selector configuration
local formatConfig = {
  awsSelector: selectors.serializeHash({
    env: '$environment',
    runtime: 'eks',
    load_balancer: { re: '$loadbalancer' },
  }),
};

basic.dashboard(
  'Runway Load Balancer Metrics - EKS',
  tags=['runway', 'type:runway', 'runway-lb', 'aws'],
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=mimirHelper.mimirDatasource('runway'),
  uid='runway-loadbalancer-aws'
)
// Environment template - hardcoded values
.addTemplate(template.custom(
  'environment',
  'production,staging',
  'production',
))
// Load balancer selection template (EKS only)
.addTemplate(template.new(
  'loadbalancer',
  '$PROMETHEUS_DS',
  'label_values(runway_lb_request_count{env="$environment", runtime="eks"}, load_balancer)',
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
      // EKS-specific: Request rate by response code class
      panel.timeSeries(
        title='Request rate by status class',
        description='Rate of EKS ALB requests grouped by HTTP status code class (2xx, 4xx, 5xx).',
        yAxisLabel='Requests per Second',
        query=|||
          sum by(response_code_class) (
            rate(
              runway_lb_response_code_count{%(awsSelector)s}[$__rate_interval]
            )
          )
        ||| % formatConfig,
        legendFormat='HTTP {{response_code_class}}',
        intervalFactor=2,
      ),

      // EKS request volume
      panel.timeSeries(
        title='Request volume by load balancer',
        description='EKS ALB request volume by individual load balancer.',
        yAxisLabel='Requests per Second',
        query=|||
          sum by(load_balancer) (
            rate(
              runway_lb_request_count{%(awsSelector)s}[$__rate_interval]
            )
          )
        ||| % formatConfig,
        legendFormat='{{load_balancer}}',
        intervalFactor=2,
      ),

      // EKS Backend latency (average)
      panel.latencyTimeSeries(
        title='Backend latency (average)',
        description='EKS ALB backend response time (average statistic).',
        yAxisLabel='Duration',
        query=|||
          runway_lb_backend_latency_milliseconds{%(awsSelector)s, statistic="average"}
        ||| % formatConfig,
        format='ms',
        legendFormat='{{load_balancer}} avg',
        intervalFactor=2,
      ),

      // EKS latency statistics comparison
      panel.latencyTimeSeries(
        title='Latency statistics',
        description='EKS ALB backend latency showing min/avg/max statistics.',
        yAxisLabel='Duration',
        query=|||
          runway_lb_backend_latency_milliseconds{%(awsSelector)s}
        ||| % formatConfig,
        format='ms',
        legendFormat='{{load_balancer}} {{statistic}}',
        intervalFactor=2,
      ),
    ]
  )
)
