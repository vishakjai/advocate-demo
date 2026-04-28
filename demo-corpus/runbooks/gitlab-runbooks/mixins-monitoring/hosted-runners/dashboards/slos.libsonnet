local sloPanels = import './panels/slos.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local grafana = import 'grafonnet/grafana.libsonnet';
local basic = import 'runbooks/libsonnet/grafana/basic.libsonnet';

local row = grafana.row;

{
  grafanaDashboards+:: {
    'hosted-runners-slos.json':
      local dashboard = basic.dashboard(
        title='Hosted Runners SLOs',
        description='Hosted Runners SLOs over the past month',
        tags=['hosted-runners', 'slas', 'service-levels'],
        editable=false,
        includeStandardEnvironmentAnnotations=false,
        includeEnvironmentTemplate=false,
        defaultDatasource=$._config.prometheusDatasource,
        time_from='now-1M/M',
        time_to='now-1d',
      );

      local panels = sloPanels.new({
        type: 'hosted-runners',
      });

      dashboard
      // Add a new row for job queuing SLO
      .addPanel(
        row.new(title='Hosted Runners Availability'),
        gridPos={ h: 1, w: 24, x: 0, y: 0 }
      )
      .addPanel(
        panels.runnerUptimeSLO,
        gridPos={ h: 8, w: 4, x: 0, y: 1 }
      )
      .addPanel(
        panels.totalOfflineHours,
        gridPos={ h: 8, w: 5, x: 4, y: 1 }
      )
      .addPanel(
        panels.downtimeHours,
        gridPos={ h: 8, w: 12, x: 9, y: 1 }
      )
      // Add a new row for job queuing SLO
      .addPanel(
        row.new(title='Hosted Runners Job Queuing SLO'),
        gridPos={ h: 1, w: 24, x: 0, y: 9 }
      )
      .addPanel(
        panels.jobQueuingSLO,
        gridPos={ h: 8, w: 4, x: 0, y: 10 }
      )
      .addPanel(
        panels.queuingViolationsCount,
        gridPos={ h: 8, w: 5, x: 4, y: 10 }
      )
      .addPanel(
        panels.jobQueuingSLOOverTime,
        gridPos={ h: 8, w: 12, x: 9, y: 10 }
      )
      .addPanel(
        row.new(title='Hosted Runners Successful Job Rate'),
        gridPos={ h: 1, w: 24, x: 0, y: 20 }
      )
      .addPanel(
        panels.overallAvailability,
        gridPos={ h: 8, w: 4, x: 0, y: 21 }
      )
      .addPanel(
        panels.budgetSpent,
        gridPos={ h: 8, w: 5, x: 4, y: 21 }
      )
      .addPanel(
        panels.rollingAvailability,
        gridPos={ h: 8, w: 12, x: 9, y: 21 }
      ),

  },
}
