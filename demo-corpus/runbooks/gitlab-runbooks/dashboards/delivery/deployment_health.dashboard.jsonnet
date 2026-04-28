local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local prometheus = grafana.prometheus;
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local annotation = grafana.annotation;
local row = grafana.row;
local statPanel = grafana.statPanel;
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local textPanel = grafana.text;
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

basic.dashboard(
  'Deployment Health',
  tags=['release'],
  editable=true,
  includeStandardEnvironmentAnnotations=true,
  includeEnvironmentTemplate=true,
)
.addTemplate(templates.stage)
.addPanel(
  row.new(title='Overview'),
  gridPos={ x: 0, y: 0, w: 24, h: 8 },
)
.addPanel(
  panel.basic(
    'Deploy Health',
    description='Showcases whether or not an environment and its stage is healthy',
    unit='none',
    legend_show=false,
  )
  .addTarget(
    prometheus.target(
      'gitlab_deployment_health:stage{env="$environment", stage="$stage"}',
      legendFormat='Health'
    ),
  ),
  gridPos={ x: 0, y: 0, w: 16, h: 12 }
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      This panel shows the Deployment Health which is taking into account all
      services for the provided $environment and $stage selected

      Values provided are effectively a boolean.  Where `1` is true, or in the
      case of metrics, a *healthy* state.  Where `0` is false, or in this case,
      *unhealthy*.

      View the **Service Deployment Health** for a breakdown of each
      contributing service that is rolled into this metric.
    |||
  ), gridPos={ x: 16, y: 0, w: 8, h: 12 }
)
.addPanel(
  basic.statPanel(
    title='',
    panelTitle='Percentage of time healthy',
    description='Percentage of time that the selected environment has been healthy over the selected time period.',
    query='gitlab_deployment_health:stage{environment="$environment",stage="$stage"}',
    reducerFunction='mean',
    colorMode='value',
    graphMode='area',
    decimals=2,
    instant=false,
    unit='percentunit',
    color=[
      { color: 'red', value: null },
      { color: 'yellow', value: 0.98 },
      { color: 'green', value: 0.9995 },
    ],
  ), gridPos={ x: 0, y: 0, w: 8, h: 12 }
)
.addPanel(
  basic.statPanel(
    title='',
    panelTitle='Amount of time unhealthy',
    description='Amount of time that the selected environment has been unhealthy over the selected time period.',
    query='(1 - gitlab_deployment_health:stage{environment="$environment",stage="$stage"}) * $__range_s',
    reducerFunction='mean',
    colorMode='value',
    graphMode='area',
    decimals=2,
    instant=false,
    unit='s',
    thresholdsMode='percentage',
    color=[
      { color: 'green', value: null },
      { color: 'yellow', value: 0.05 },
      { color: 'red', value: 2 },
    ],
  ), gridPos={ x: 8, y: 0, w: 8, h: 12 }
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      These panels show the percentage of time that the selected environment ($environment-$stage)
      has been healthy and the amount of time it has been unhealthy. They take into account
      all services for $environment-$stage.

      The deployment health metric (and consequently the environment) is considered to be in
      "unhealthy" state when the apdex or error metric for one or more services
      crosses the deployment threshold. See
      https://gitlab.com/gitlab-org/release-tools/-/blob/master/doc/deployment_health_metrics.md
      for details about the deployment health metrics.

      View the **Service Deployment Health** for a breakdown of each
      contributing service that is rolled into this metric.
    |||
  ), gridPos={ x: 16, y: 0, w: 8, h: 12 }
)

.addPanel(
  row.new(title='Service Breakdown'),
  gridPos={ x: 0, y: 1, w: 24, h: 8 },
)
.addPanel(
  panel.basic(
    'Service Deployment Health',
    description='Showcases whether or not the environments stage is healthy with a breakdown by the individual services that contribute to the metric',
    fill=100,
    stack=true,
  )
  .addTarget(
    prometheus.target(
      'gitlab_deployment_health:service{env="$environment", stage="$stage", type!="registry"}',
      legendFormat='{{type}}',
    ),
  ),
  gridPos={ x: 0, y: 1, w: 16, h: 12 }
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      This panel shows the Deployment Health which is showcasing each of the
      services that are a blocker for deployments.

      Values provided are effectively a boolean.  Where `1` is true, or in the
      case of metrics, a *healthy* state.  Where `0` is false, or in this case,
      *unhealthy*.

      We are using a stack chart to show case each metric individually in an
      easier fashion.

      View the **Component Breakdown** for a breakdown of each contributing
      metric that is rolled into this metrics.
    |||
  ), gridPos={ x: 16, y: 1, w: 8, h: 12 }
)

.addPanel(
  row.new(title='Component Breakdown'),
  gridPos={ x: 0, y: 2, w: 24, h: 8 },
)
.addTemplate(templates.type)
.addPanel(
  panel.basic(
    'Component Deployment Health',
    description='Showcases whether or not the environments stage is healthy with a breakdown by the individual services that contribute to the metric',
    fill=100,
    stack=true,
  )
  .addTarget(
    prometheus.target(
      'gitlab_deployment_health:service:apdex{env="$environment", stage="$stage", type="$type"}',
      legendFormat='Apdex',
    ),
  )
  .addTarget(
    prometheus.target(
      'gitlab_deployment_health:service:errors{env="$environment", stage="$stage", type="$type"}',
      legendFormat='Errors',
    ),
  ),
  gridPos={ x: 0, y: 2, w: 16, h: 12 }
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      This panel shows the Deployment Health which is showcasing each of the
      contributing factors, Apdex, and Error SLI's and whether or not they
      are within the service boundaries.

      Values provided are effectively a boolean.  Where `1` is true, or in the
      case of metrics, a *healthy* state.  Where `0` is false, or in this case,
      *unhealthy*.

      We're using a stack chart to show case each metric individually in an
      easier fashion.
    |||
  ), gridPos={ x: 16, y: 2, w: 8, h: 12 }
)

.addPanel(
  row.new(title='Degraded Services'),
  gridPos={ x: 0, y: 3, w: 24, h: 8 },
)
.addPanel(
  basic.table(
    'Currently Degraded Services',
    description='Lists currently degraded service and stage combinations across all stages. "No degraded services" means all services are healthy. See Service Deployment Health above for full context.',
    query=|||
      label_replace(
        label_replace(
          gitlab_deployment_health:service{env="$environment", type!="registry"} == 0
          or on() vector(0),
          "type", "No degraded services", "type", "^$"
        ),
        "stage", "-", "stage", "^$"
      )
    |||,
    styles=[
      { pattern: 'Time', type: 'hidden' },
      { pattern: '__name__', type: 'hidden' },
      { pattern: 'env', type: 'hidden' },
      { pattern: 'environment', type: 'hidden' },
      { pattern: 'job', type: 'hidden' },
      { pattern: 'monitor', type: 'hidden' },
      { pattern: 'prometheus', type: 'hidden' },
      { pattern: 'prometheus_replica', type: 'hidden' },
      { pattern: 'tier', type: 'hidden' },
      { pattern: 'Value', type: 'hidden' },
      { pattern: 'stage', alias: 'Stage', type: 'string' },
      { pattern: 'type', alias: 'Service', type: 'string' },
    ],
  ),
  gridPos={ x: 0, y: 3, w: 16, h: 12 }
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      This table shows **currently degraded** service and stage combinations
      across all stages in the selected environment, e.g. main-api, cny-api,
      main-git, cny-git.

      **"No degraded services"** means all services are healthy.

      For full health status across all services and stages, and for historical
      context, see the **Service Deployment Health** panel above.
    |||
  ), gridPos={ x: 16, y: 3, w: 8, h: 12 }
)

.addPanel(
  row.new(title='Component Deployment Health Breakdown'),
  gridPos={ x: 0, y: 15, w: 24, h: 8 },
)
.addPanel(
  textPanel.new(
    title='Details',
    content=|||
      Utilize the below links to browse to the various dashboards that
      showcases the burnrates for the various windows of time that contribute
      towards to deployment health metric for the selected component, stage,
      and environment.
        - [Error SLO Analysis](https://dashboards.gitlab.net/d/alerts-service_slo_error/alerts-global-service-aggregated-metrics-error-slo-analysis?orgId=1&var-environment=%(environment)s&var-type=%(type)s&var-stage=%(stage)s&var-proposed_slo=0.999)
        - [Apdex SLO Analysis](https://dashboards.gitlab.net/d/alerts-service_slo_apdex/alerts-global-service-aggregated-metrics-apdex-slo-analysis?orgId=1&var-environment=%(environment)s&var-type=%(type)s&var-stage=%(stage)s&var-proposed_slo=0.997)
    ||| % { environment: '$environment', type: '$type', stage: '$stage' }
  ), gridPos={ x: 0, y: 15, w: 8, h: 8 }
)
.trailer()
