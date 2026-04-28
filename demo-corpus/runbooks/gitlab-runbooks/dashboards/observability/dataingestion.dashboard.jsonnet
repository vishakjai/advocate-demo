local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local templates = import 'grafana/templates.libsonnet';
local template = grafana.template;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Data Ingestion',
  tags=[
    'gitlab-observability',
  ],
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-observability')
)
.addTemplate(
  template.custom(
    name='environment',
    label='Environment',
    query='gstg,gprd',
    current='gprd',
  )
)
.addTemplate(template.new(
  'namespace',
  '$PROMETHEUS_DS',
  'label_values(analytics_events_total_count{env="$environment", cluster=~"opstrace-.*"}, namespace_id)',
  label='Namespace',
  refresh='load',
  sort=1,
))
.addTemplate(template.new(
  'project',
  '$PROMETHEUS_DS',
  'label_values(analytics_events_total_count{env="$environment", cluster=~"opstrace-.*"}, project_id)',
  label='Project',
  refresh='load',
  sort=1,
))
.addPanel(
  row.new(title='Number of events ingested per environment'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Metrics',
        query=|||
          sum(analytics_events_total_count{env="$environment"}) by (env)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{feature_name}}',
        stack=true,
      ),
    ],
    cols=1,
    startRow=1,
  )
)
.addPanel(
  row.new(title='Number of events ingested per feature'),
  gridPos={ x: 0, y: 100, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Metrics',
        query=|||
          sum(analytics_events_total_count{feature_name="metrics", env="$environment"}) by (feature_name)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{feature_name}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Traces',
        query=|||
          sum(analytics_events_total_count{feature_name="tracing", env="$environment"}) by (feature_name)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{feature_name}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Logs',
        query=|||
          sum(analytics_events_total_count{feature_name="logging", env="$environment"}) by (feature_name)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{feature_name}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Error Tracking',
        query=|||
          sum(analytics_events_total_count{feature_name="errortracking", env="$environment"}) by (feature_name)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{feature_name}}',
        stack=true,
      ),
    ], cols=2, startRow=101
  )
)
.addPanel(
  row.new(title='Top event producers'),
  gridPos={ x: 0, y: 200, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Top 10 by namespace',
        query=|||
          topk(10, sum(analytics_events_total_count{env="$environment"}) by (feature_name, namespace_id))
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{feature_name}} - {{namespace_id}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Top 10 by project',
        query=|||
          topk(10, sum(analytics_events_total_count{env="$environment"}) by (feature_name, project_id))
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{feature_name}} - {{project_id}}',
        stack=true,
      ),
    ], cols=2, startRow=201
  )
)
.addPanel(
  row.new(title='Number of events ingested by project'),
  gridPos={ x: 0, y: 300, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Metrics',
        query=|||
          sum(analytics_events_total_count{feature_name="metrics", env="$environment", project_id="$project"}) by (feature_name, project_id)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{project_id}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Traces',
        query=|||
          sum(analytics_events_total_count{feature_name="tracing", env="$environment", project_id="$project"}) by (feature_name, project_id)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{project_id}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Logs',
        query=|||
          sum(analytics_events_total_count{feature_name="logging", env="$environment", project_id="$project"}) by (feature_name, project_id)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{project_id}}',
        stack=true,
      ),
      panel.timeSeries(
        title='Error Tracking',
        query=|||
          sum(analytics_events_total_count{feature_name="errortracking", env="$environment", project_id="$project"}) by (feature_name, project_id)
        |||,
        yAxisLabel='count',
        fill=50,
        legendFormat='{{project_id}}',
        stack=true,
      ),
    ], cols=4, startRow=301
  )
)
