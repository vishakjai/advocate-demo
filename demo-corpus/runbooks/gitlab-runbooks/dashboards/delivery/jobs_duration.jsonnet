local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prometheus = grafana.prometheus;
local graphPanel = grafana.graphPanel;
local templates = import 'grafana/templates.libsonnet';
local template = grafana.template;
local promQuery = import 'grafana/prom_query.libsonnet';
local colorScheme = import 'grafana/color_scheme.libsonnet';
local row = grafana.row;

local bargaugePanel(
  title,
  description='',
  query='',
  legendFormat='',
  thresholds={},
  links=[],
  fieldLinks=[],
  orientation='horizontal',
      ) =
  {
    description: description,
    fieldConfig: {
      values: false,
      defaults: {
        color: {
          mode: 'continuous-BlPu',
        },
        reduceOptions: {
          calcs: [
            'last',
          ],
        },
        thresholds: thresholds,
        unit: 's',
        links: fieldLinks,
        mode: 'thresholds',
      },
    },
    links: links,
    options: {
      displayMode: 'gradient',
      orientation: orientation,
      showUnfilled: true,
      minVizWidth: 0,
      minVizHeight: 10,
    },
    pluginVersion: '9.3.6',
    targets: [promQuery.target(query, legendFormat=legendFormat, instant=true)],
    title: title,
    type: 'bargauge',
  };

local bargaugePanelProject(
  title,
  description='',
  query='',
  legendFormat='',
  thresholds={},
  links=[],
  fieldLinks=[],
  orientation='horizontal',
      ) =
  {
    description: description,
    fieldConfig: {
      values: false,
      defaults: {
        color: {
          mode: 'continuous-BlPu',
        },
        reduceOptions: {
          calcs: [
            'last',
          ],
        },
        thresholds: thresholds,
        unit: 's',
        links: fieldLinks,
        mode: 'thresholds',
      },
    },
    links: links,
    options: {
      displayMode: 'gradient',
      orientation: orientation,
      showUnfilled: true,
      minVizWidth: 0,
      minVizHeight: 10,
    },
    pluginVersion: '9.3.6',
    targets: [promQuery.target(query, legendFormat=legendFormat, instant=true)],
    title: title,
    type: 'bargauge',
  };


basic.dashboard(
  'jobs-duration',
  tags=[],
  editable=true,
  time_from='now-6h',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource='mimir-gitlab-ops',
)

.addTemplate(
  template.new(
    'deploy_version',
    '$PROMETHEUS_DS',
    'label_values(delivery_deployment_job_duration_seconds, deploy_version)',
    label='Version',
    refresh='time',
    sort=2,
  )
)
.addTemplate(
  template.new(
    'job_name',
    '$PROMETHEUS_DS',
    'label_values(delivery_deployment_job_duration_seconds, job_name)',
    label='Job',
    refresh='time',
    sort=2,
  )
)

.addPanel(
  row.new(title='Jobs'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)

.addPanels(
  layout.columnGrid([
    [
      basic.statPanel(
        title='',
        panelTitle='Job Duration',
        description='Median duration over the selected time range',
        query='\n          quantile(0.5,\n            last_over_time(delivery_deployment_job_duration_seconds{job_name="$job_name"}[$__range])\n              unless\n            last_over_time(delivery_deployment_job_duration_seconds{job_name="$job_name"}[12h] offset $__range)\n          )',
        legendFormat='Median',
        colorMode='value',
        textMode='value',
        graphMode='area',
        decimals=2,
        color='',
      )
      .addTarget(
        promQuery.target(
          'max(\n            last_over_time(delivery_deployment_job_duration_seconds{job_name="$job_name"}[$__range])\n              unless\n            last_over_time(delivery_deployment_job_duration_seconds{job_name="$job_name"}[12h] offset $__range)\n          )',
          legendFormat='Max',
          instant=true
        )
      ) {
        fieldConfig+: {
          defaults+: {
            unit: 's',
            color: {
              mode: 'continuous-BlPu',
            },
          },
        },
      },
    ],
  ], [7], rowHeight=10, startRow=0)
)

.addPanels(
  layout.grid(
    [
      bargaugePanel(
        'Top 10 job duration per deployment',
        description='Top 10 job duration per deployment',
        query='topk(10, avg by(job_name)(delivery_deployment_job_duration_seconds{deploy_version="$deploy_version"}))',
        legendFormat='{{deploy_version}}',
      ),
    ], cols=1, startRow=1
  )
)

.addPanels(
  layout.grid(
    [
      bargaugePanelProject(
        'Maximum job duration per project',
        description='Maximum job duration per project, eg, gprd-gitaly takes most of the duration in `deployer` project.',
        query='max by(project_name)(delivery_deployment_job_duration_seconds)',
        legendFormat='{{deploy_version}}',
      ),
    ], cols=1, startRow=2
  )
)
.trailer()
