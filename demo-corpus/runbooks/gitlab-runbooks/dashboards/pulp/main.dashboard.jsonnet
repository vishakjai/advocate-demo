local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local template = grafana.template;

local environmentTemplate =
  template.new(
    'environment',
    '$PROMETHEUS_DS',
    'label_values(gitlab_service_ops:rate_1h, environment)',
    current='ops',
    refresh='load',
    sort=1,
  );

serviceDashboard.overview(
  'pulp',
  omitEnvironmentDropdown=true,
)
.addTemplate(environmentTemplate)
.overviewTrailer()
.addPanel(
  row.new(title='Pulp Task Queue'),
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
      panel.latencyTimeSeries(
        title='Longest Unblocked Task Wait Time',
        description='How long the oldest unblocked task has been waiting in the queue. Lower is better.',
        query='tasks_longest_unblocked_time_seconds{namespace="pulp"}',
        legendFormat='Longest Wait Time',
        format='s',
        yAxisLabel='Duration',
        interval='1m',
        intervalFactor=1,
        min=0,
        thresholdMode='absolute',
        thresholdSteps=[
          { value: 0, color: 'green' },
          { value: 300, color: 'yellow' },
          { value: 600, color: 'red' },
        ],
      ),
      panel.queueLengthTimeSeries(
        title='Unblocked Task Queue Length',
        description='The number of unblocked tasks waiting to be processed. Lower is better.',
        query='tasks_unblocked_queue{namespace="pulp"}',
        legendFormat='Queue Length',
        format='short',
        interval='1m',
        intervalFactor=1,
        yAxisLabel='Tasks',
      ),
    ], cols=2, rowHeight=10, startRow=1001
  ),
)
