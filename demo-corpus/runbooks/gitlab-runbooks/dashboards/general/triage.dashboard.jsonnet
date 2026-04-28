local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local annotation = grafana.annotation;
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';
local colorScheme = import 'grafana/color_scheme.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local sliPromQL = import 'key-metric-panels/sli_promql.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local override = import 'grafana/time-series/override.libsonnet';
local threshold = import 'grafana/time-series/threshold.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local rowHeight = 8;
local colWidth = 12;

local genGridPos(x, y, h=1, w=1) = {
  x: x * colWidth,
  y: y * rowHeight,
  w: w * colWidth,
  h: h * rowHeight,
};

local selector = { env: '$environment', environment: '$environment', stage: '$stage' };

local generalGraphPanel(title, description=null, sort='increasing', unit=null) =
  panel.basic(
    title,
    linewidth=2,
    description=description,
    unit=unit
  )
  .addSeriesOverride(override.sloViolation);

local generateAnomalyPanel(title, query, minY=6, maxY=6, errorThreshold=8, warningThreshold=6, sort='increasing') =
  panel.basic(
    title,
    description='Each timeseries represents the distance, in standard deviations, that each service is away from its normal range. The further from zero, the more anomalous',
    linewidth=2,
    legend_min=false,
    legend_max=false,
    legend_current=false,
    legend_avg=false,
    legend_alignAsTable=false,
    unit='short',
    thresholdSteps=[
      threshold.errorLevel(errorThreshold),
      threshold.warningLevel(warningThreshold),
      threshold.warningLevel(-warningThreshold),
      threshold.errorLevel(-errorThreshold),
    ]
  )
  .addTarget(
    target.prometheus(
      |||
        clamp_min(
          clamp_max(
            avg(%(query)s) by (type),
            %(maxY)f),
          %(minY)f)
      ||| % {
        minY: minY,
        maxY: maxY,
        query: query,
      },
      legendFormat='{{ type }} service',
      intervalFactor=3,
    )
  )
  .addYaxis(
    label='Sigma σ',
    min=minY,
    max=maxY,
  );

basic.dashboard(
  'Platform Triage',
  tags=['general'],
)
.addAnnotation(
  annotation.datasource(
    'pdm',
    '-- Grafana --',
    enable=false,
    tags=['pdm', '$environment'],
    builtIn=1,
    iconColor='#494ecc',
  )
)
.addTemplate(templates.stage)
.addPanel(
  generalGraphPanel(
    'Latency: Apdex',
    description='Apdex is a measure of requests that complete within a tolerable period of time for the service. Higher is better.',
    sort='increasing',
    unit='percentunit',
  )
  .addTarget(  // Primary metric
    target.prometheus(
      sliPromQL.apdexQuery(aggregationSets.serviceSLIs, null, selector, range='$__interval'),
      legendFormat='{{ type }} service',
      intervalFactor=3,
    )
  )
  .addYaxis(
    max=1,
    label='Apdex %',
  ),
  gridPos=genGridPos(0, 0.5, w=2)
)
.addPanel(
  generalGraphPanel(
    'Error Ratios',
    description='Error rates are a measure of unhandled service exceptions within a minute period. Client errors are excluded when possible. Lower is better',
    sort='decreasing',
    unit='percentunit',
  )
  .addTarget(  // Primary metric
    target.prometheus(
      sliPromQL.errorRatioQuery(aggregationSets.serviceSLIs, null, selectorHash=selector, range='$__interval', clampMax=0.15),
      legendFormat='{{ type }} service',
      intervalFactor=3,
    )
  )
  .addYaxis(
    min=0,
    label='Error Rate %',
  ),
  gridPos=genGridPos(0, 1.5, w=1)
)
.addPanel(
  grafana.text.new(
    title='Error Ratios Information',
    mode='markdown',
    content=|||
      This panel displays error rates for various services, but **values are clamped at 15%** to prevent high error rates from obscuring other services.

      ### What does this mean?

      * Actual error rates may be significantly higher than what is displayed
      * When you see a service at or near 15%, it indicates a significant issue
      * The clamping helps maintain visibility of all services on the same graph

      ### What to do from here?

      * Check the service-specific dashboard for the exact error rate
      * Services showing at or near the 15% cap require immediate investigation
    |||,
  ),
  gridPos=genGridPos(2, 1.5, h=1, w=1)
)
.addPanel(
  generalGraphPanel(
    'Service Requests per Second',
    description='The operation rate is the sum total of all requests being handle for all components within this service. Note that a single user request can lead to requests to multiple components. Higher is busier.',
    sort='decreasing',
  )
  .addTarget(  // Primary metric
    target.prometheus(
      sliPromQL.opsRateQuery(aggregationSets.serviceSLIs, selector, range='$__interval'),
      legendFormat='{{ type }} service',
      intervalFactor=3,
    )
  )
  .addYaxis(
    label='Operations per Second',
  ),
  gridPos=genGridPos(0, 2.5)
)
.addPanel(
  generateAnomalyPanel(
    'Anomaly detection: Requests per second',
    |||
      (
        gitlab_service_ops:rate_5m{%(selector)s}
        -
        gitlab_service_ops:rate:prediction{%(selector)s}
      )
      /
      gitlab_service_ops:rate:stddev_over_time_1w{%(selector)s}
    ||| % {
      selector: selectors.serializeHash(selector),
    },
    maxY=6,
    minY=-3,
    errorThreshold=4,
    warningThreshold=3,
    sort='decreasing',
  ),
  gridPos=genGridPos(1, 2.5)
)
.addPanel(
  // TODO: get rid of this: aggregating these saturation values in this manner makes litter sense
  generalGraphPanel(
    'Saturation',
    description='Saturation is a measure of the most saturated component of the service. Lower is better.',
    sort='decreasing',
  )
  .addTarget(  // Primary metric
    target.prometheus(
      |||
        max(
          max_over_time(
            gitlab_component_saturation:ratio{environment="$environment", stage="$stage"}[$__interval]
          )
        ) by (type)
      |||,
      legendFormat='{{ type }} service',
      intervalFactor=3,
    )
  )
  .addYaxis(
    max=1,
    label='Availability %',
  ),
  gridPos=genGridPos(0, 4.5, w=2)
)
+ {
  links+: platformLinks.services,
}
