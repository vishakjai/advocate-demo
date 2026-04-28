local common = import 'common.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';

local workspaceSetupDurationQuery = common.makeDurationQuery('workspace_setup_duration');

local workspaceSetupDurationByStepQuery = common.makeDurationByStepQuery('workspace_setup_duration');

local workspaceSetupSuccessRateQuery = |||
  SELECT
    date_trunc('week', collector_tstamp) as time,
    round(avg(success), 3) as success_rate
  FROM
    (
      SELECT
        collector_tstamp,
        if(JSONExtractString(COALESCE(JSONExtractString(custom_event_props, 'extras'), '{}'), 'success') = 'true', 1.0, 0.0) as success
      FROM
        default.events
      WHERE
        custom_event_name = 'Custom workspace_setup_duration'
        AND collector_tstamp >= date_trunc('week', date_add(WEEK, -14, now()))
        AND JSONHas(COALESCE(JSONExtractString(custom_event_props, 'extras'), '{}'), 'success')
    )
  GROUP BY time
  ORDER BY time ASC
|||;

local workspaceSetupRow(y) =
  layout.titleRowWithPanels(
    'Workspace setup duration',
    [
      common.makeDurationPanel(workspaceSetupDurationQuery) + {
        title: 'Workspace setup duration',
        gridPos: { h: 8, w: 12, x: 0, y: 2 },
        fieldConfig+: {
          defaults+: { unit: 's' },
        },
      },
      common.makeDurationPanel(workspaceSetupDurationByStepQuery) + {
        title: 'Workspace setup duration breakdown',
        gridPos: { h: 8, w: 12, x: 12, y: 2 },
        fieldConfig+: {
          defaults+: { unit: 's' },
        },
      },
    ],
    true,
    y
  );

local dashboard = basic.dashboard(
  'GDK Workspaces',
  tags=['gdk'],
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource='GitLab Development Kit ClickHouse'
).addPanels([
  common.makeDurationPanel(workspaceSetupDurationQuery) + {
    title: 'Workspace setup duration',
    gridPos: { h: 8, w: 8, x: 0, y: 1 },
    fieldConfig+: { defaults+: { unit: 's' } },
  },
  common.makeDurationPanel(workspaceSetupDurationByStepQuery) + {
    title: 'Workspace setup duration breakdown',
    gridPos: { h: 8, w: 8, x: 8, y: 1 },
    fieldConfig+: { defaults+: { unit: 's' } },
  },
  common.makeSuccessRatePanel(workspaceSetupSuccessRateQuery) + {
    title: 'Workspace setup success rate',
    gridPos: { h: 8, w: 8, x: 16, y: 1 },
  },
]) + {
  time: {
    from: 'now-14w',
    to: 'now',
  },
  refresh: '1h',
};

// Override to remove all template variables
(dashboard {
   templating: { list: [] },
 }).trailer()
