local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local statPanel = grafana.statPanel;
local colorScheme = import 'grafana/color_scheme.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Rails Detail',
  tags=['container registry', 'registry', 'rails'],
)
.addTemplate(templates.gkeCluster)
.addTemplate(templates.stage)
.addTemplate(templates.namespaceGitlab)
.addTemplate(
  template.custom(
    'Deployment',
    'gitlab-registry,',
    'gitlab-registry',
    hide='variable',
  )
)
.addPanel(
  row.new(title='Repository Async Deletions'),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='In-progress',
        description='The number of in-progress async container repository deletions.',
        yAxisLabel='Count',
        query=|||
          avg (
              gitlab_database_rows{query_name="container_repositories_delete_ongoing", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
      panel.timeSeries(
        title='Failed',
        description='The number of failed async container repository deletions.',
        yAxisLabel='Count',
        query=|||
          avg (
              gitlab_database_rows{query_name="container_repositories_delete_failed", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
      panel.timeSeries(
        title='Scheduled',
        description='The number of scheduled async container repository deletions.',
        yAxisLabel='Count',
        query=|||
          avg (
            gitlab_database_rows{query_name="container_repositories_delete_scheduled", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
      panel.timeSeries(
        title='Staled',
        description='The number of staled async container repository deletions.',
        yAxisLabel='Count',
        query=|||
          avg (
            gitlab_database_rows{query_name="container_repositories_delete_staled", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
    ],
    cols=4,
    rowHeight=4,
    startRow=1,
  )
)
.addPanel(
  row.new(title='Tag Cleanup Policies'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Enabled',
        description='The number of enabled tag cleanup policies.',
        yAxisLabel='Count',
        query=|||
          avg (
            gitlab_database_rows{query_name="container_repositories_cleanup_enabled", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
      panel.timeSeries(
        title='In-progress',
        description='The number of in-progress tag cleanup policies.',
        yAxisLabel='Count',
        query=|||
          avg (
            gitlab_database_rows{query_name="container_repositories_cleanup_ongoing", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
      panel.timeSeries(
        title='Pending',
        description='The number of pending tag cleanup policies.',
        yAxisLabel='Count',
        query=|||
          avg (
            gitlab_database_rows{query_name="container_repositories_cleanup_pending", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
      panel.timeSeries(
        title='Scheduled',
        description='The number of scheduled tag cleanup policies.',
        yAxisLabel='Count',
        query=|||
          avg (
            gitlab_database_rows{query_name="container_repositories_cleanup_scheduled", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
      panel.timeSeries(
        title='Staled',
        description='The number of staled tag cleanup policies.',
        yAxisLabel='Count',
        query=|||
          avg (
            gitlab_database_rows{query_name="container_repositories_cleanup_staled", environment="$environment"}
          )
        |||,
        legend_show=false
      ),
      panel.timeSeries(
        title='Unfinished',
        description='The number of unfinished tag cleanup policies.',
        yAxisLabel='Count',
        query=|||
          avg (
            gitlab_database_rows{query_name="container_repositories_cleanup_unfinished", environment="$environment"}
          )
        |||
      ),
    ],
    cols=6,
    rowHeight=4,
    startRow=1001,
  ),
)
