local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prometheus = grafana.prometheus;
local template = grafana.template;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local sloQuery = |||
  sum(rate(delivery_deployment_duration_seconds_bucket{job="delivery-metrics",status="success",le=~"$target_slo(.0)?"}[$__range]))
  /
  sum(rate(delivery_deployment_duration_seconds_count{job="delivery-metrics",status="success"}[$__range]))
|||;
local numberOfDeploymentQuery = 'sum(increase(delivery_deployment_duration_seconds_count{job="delivery-metrics",status="success"}[$__range]))';

local explainer = |||
  This dashboard shows a summary of deployments on gitlab.com.

  This section of the dashboard is governed by the `target SLO` variable.

  - __# deployments__ counts the number of deployments in the time range`
  - __Target SLO__ is the amount of seconds we consider acceptable for a complete deployment from gstg-cny (staging canary) to production (gprd). We track this using a [Histogram](https://prometheus.io/docs/practices/histograms/) that consists of 14 predefined buckets, each of length 30 minutes, starting from 3.5 hours to 10 hours.
    - See [`metrics.go`](https://gitlab.com/gitlab-org/release-tools/-/blob/master/metrics/metrics.go#L82) within release/tools for the latest bucket definition.
  - __Apdex Score__ shows the percentage of completed deploymens in the time range that matched the `target SLO`. Note that deployments which were never promoted to the main stages or never started do not affect this score adversely.
    - That is, in the extreme case where we don't deploy at all, this score will show up as 100%
  - __Apdex__ shows the Apdex score over time
|||;

local packager_pipeline_duration_query = |||
  sum
    (
      last_over_time(delivery_deployment_pipeline_duration_seconds{project_name="%(project_name)s"}[30m])
      unless last_over_time(delivery_deployment_pipeline_duration_seconds{project_name="%(project_name)s"}[60m] offset 30m)
    )
|||;

local coordinated_pipeline_duration_query = |||
  sum (
    last_over_time(delivery_deployment_pipeline_duration_seconds{project_name="gitlab-org/release/tools",pipeline_name=~"Deployment pipeline - .*"}[30m])
    unless last_over_time(delivery_deployment_pipeline_duration_seconds{project_name="gitlab-org/release/tools",pipeline_name=~"Deployment pipeline - .*"}[60m] offset 30m)
  )
|||;

local pipeline_duration_explainer = |||


  In case outliers are seen in this panel, this panel's query can be updated to `sum with (deploy_version)` and the deployment pipeline with the outlier duration can be identified.
|||;

local packagerPipelineDataLink = {
  url: '${__field.labels.web_url}',
  title: 'Packager pipeline',
};

local packagerPipelineDurationPanel(title, pipelineType, projectName, withDeployVersion=false) =
  local basePanel = panel.basic(
    title,
    description='Time taken for individual ' + pipelineType + ' packager pipelines to complete.' + if withDeployVersion then '' else pipeline_duration_explainer,
    unit='s',
    linewidth=0,
    points=true,
    legend_min=false,
    legend_max=false,
    legend_current=false,
    legend_total=false,
    legend_avg=false,
    custom_legends=if withDeployVersion then ['last'] else ['p50', 'p80', 'p90', 'max'],
  ).addYaxis(
    min=0,
    label='Duration',
  ).addTarget(
    prometheus.target(
      packager_pipeline_duration_query % { project_name: projectName } + if withDeployVersion then ' by (deploy_version, web_url)' else '',
      legendFormat=if withDeployVersion then '{{ deploy_version }}' else 'Duration',
    )
  );

  if withDeployVersion then basePanel.addDataLink(packagerPipelineDataLink) else basePanel;

local coordinatedPipelineDataLink = {
  url: '${__field.labels.web_url}',
  title: 'Coordinated pipeline',
};

local coordinatedPipelineDurationPanel(withDeployVersion=false) =
  local basePanel = panel.basic(
    'Coordinated pipeline duration',
    description='Time taken for individual coordinated pipelines for promoted deployments that completed successfully.' + if withDeployVersion then '' else pipeline_duration_explainer,
    unit='s',
    linewidth=0,
    points=true,
    legend_min=false,
    legend_max=false,
    legend_current=false,
    legend_total=false,
    legend_avg=false,
    custom_legends=if withDeployVersion then ['last'] else ['p50', 'p80', 'p90', 'max'],
  ).addYaxis(
    label='Duration',
  ).addTarget(
    prometheus.target(
      coordinated_pipeline_duration_query + if withDeployVersion then ' by (deploy_version, web_url)' else '',
      legendFormat=if withDeployVersion then '{{ deploy_version }}' else 'Duration',
    )
  );

  if withDeployVersion then basePanel.addDataLink(coordinatedPipelineDataLink) else basePanel;


basic.dashboard(
  'Deployment SLO',
  tags=['release'],
  editable=true,
  time_from='now-30d',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-ops'),
)
.addTemplate(template.custom(
  // Data since 2025-03-31 is stored and returned with the label `le` as a float (le=28800.0) Data before that date is stored with an integer label (le=28800). So, we have to support both integer and floating point values of `le` for at least the next one year. After 2026-03-31, we can change this back to a dynamic query that gets the label values from Prometheus
  name='target_slo',
  query='3.5 hours : 12600, 4 hours : 14400, 4.5 hours : 16200, 5 hours : 18000, 5.5 hours : 19800, 6 hours : 21600, 6.5 hours : 23400, 7 hours : 25200, 7.5 hours : 27000, 8 hours : 28800, 8.5 hours : 30600, 9 hours : 32400, 9.5 hours : 34200, 10 hours : 36000,',
  current='28800',
  label='target SLO',
))

.addPanel(
  grafana.row.new(title='Deployment SLO'),
  gridPos={
    x: 0,
    y: 0,
    w: 12,
    h: 24,
  }
)

.addPanels(
  layout.singleRow([
    grafana.text.new(
      title='Deployment SLO Explainer',
      mode='markdown',
      content=explainer,
    ),
  ], rowHeight=10, startRow=0)
)

// Number of deployments
.addPanels(layout.grid([
  basic.statPanel(
    title='',
    panelTitle='# deployments',
    colorMode='value',
    legendFormat='',
    query=numberOfDeploymentQuery,
    color=[
      { color: 'red', value: null },
      { color: 'green', value: 1 },
    ]
  ),
  basic.statPanel(
    '',
    'Target SLO',
    color='',
    query='topk(1, count(delivery_deployment_duration_seconds_bucket{job="delivery-metrics",le=~"$target_slo(.0)?"}) by (le))',
    instant=false,
    legendFormat='{{le}}',
    format='table',
    unit='s',
    fields='/^le$/',
    colorMode='none',
    textMode='value',
  ),
  basic.statPanel(
    title='',
    panelTitle='Apdex score',
    legendFormat='',
    query=sloQuery,
    decimals=1,
    unit='percentunit',
    color=[
      { color: 'red', value: null },
      { color: 'yellow', value: 0.5 },
      { color: 'green', value: 0.95 },
    ]
  ),
], cols=3, rowHeight=4, startRow=100))


.addPanels(
  layout.grid(
    [
      coordinatedPipelineDurationPanel(),
      // Apdex
      panel.apdexTimeSeries(
        description='Apdex is a measure of deployments that complete within an acceptable threshold duration. Actual threshold can be adjusted using the target SLO variable above in this page. Higher is better.',
        yAxisLabel='% Deployments w/ satisfactory duration',
        legendFormat='% Deployments completed within target SLO',
        legend_min=false,
        legend_max=false,
        legend_current=false,
        legend_total=false,
        legend_avg=false,
        custom_legends=['min', 'mean', 'max'],
        query=sloQuery,
      ),
    ],
    startRow=200,
  ),
)

.addPanels(
  layout.grid(
    [
      grafana.row.new(title='Packager pipeline duration'),
      packagerPipelineDurationPanel(
        'Duration of Omnibus packager pipelines',
        'Omnibus',
        'gitlab/omnibus-gitlab'
      ),
      packagerPipelineDurationPanel(
        'Duration of CNG packager pipelines',
        'CNG',
        'gitlab/charts/components/images'
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=300,
  )
)
.addPanels(
  layout.grid(
    [
      grafana.row.new(title='Coordinated pipeline duration by deployment version', collapse=true)
      .addPanels(
        layout.grid(
          [
            coordinatedPipelineDurationPanel(withDeployVersion=true),
          ],
          cols=2
        )
      ),
    ],
    rowHeight=10,
    startRow=400,
  )
)
.addPanels(
  layout.grid(
    [
      grafana.row.new(title='Packager pipeline duration by deployment version', collapse=true)
      .addPanels(
        layout.grid(
          [
            packagerPipelineDurationPanel(
              'Duration of CNG packager pipelines',
              'CNG',
              'gitlab/charts/components/images',
              withDeployVersion=true
            ),
            packagerPipelineDurationPanel(
              'Duration of Omnibus packager pipelines',
              'Omnibus',
              'gitlab/omnibus-gitlab',
              withDeployVersion=true
            ),
          ],
          cols=2,
        )
      ),
    ],
    rowHeight=10,
    startRow=500
  )
)
.trailer()
