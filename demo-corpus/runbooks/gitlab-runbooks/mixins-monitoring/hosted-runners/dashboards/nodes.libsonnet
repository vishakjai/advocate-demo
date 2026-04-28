local nodesPanels = import './panels/nodes.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local grafana = import 'grafonnet/grafana.libsonnet';
local basic = import 'runbooks/libsonnet/grafana/basic.libsonnet';

local row = grafana.row;

{
  grafanaDashboards+:: {
    'hosted-runner-nodes.json':
      local dashboard = basic.dashboard(
        title='%s Nodes' % $._config.dashboardName,
        tags=$._config.dashboardTags,
        editable=true,
        includeStandardEnvironmentAnnotations=false,
        includeEnvironmentTemplate=false,
        defaultDatasource=$._config.prometheusDatasource
      )
                        .addTemplate($._config.templates.stackSelector)
                        .addTemplate($._config.templates.shardSelector)
                        .addTemplate(
        {
          name: 'service',
          type: 'query',
          query: 'label_values(node_uname_info{type="hosted-runners", shard=~".+-(${stack:pipe})", shard=~"$shard"},service)',
          includeAll: false,
          refresh: 1,
        }
      )
                        .addTemplate(
        {
          name: 'instance',
          type: 'query',
          query: 'label_values(node_uname_info{type="hosted-runners", service="$service", shard=~".+-(${stack:pipe})", shard=~"$shard"},instance)',
          label: 'Instance',
          refresh: 2,
        }
      );

      local panels = nodesPanels.new({
        instance: '$instance',
      });

      dashboard
      .addPanel(
        row.new(title='CPU'),
        gridPos={ h: 1, w: 24, x: 0, y: 0 }
      )
      .addPanel(
        panels.cpuUsage,
        gridPos={ h: 7, w: 12, x: 0, y: 1 }
      )
      .addPanel(
        panels.loadAverage,
        gridPos={ h: 7, w: 12, x: 12, y: 1 }
      )
      .addPanel(
        row.new(title='Memory'),
        gridPos={ h: 1, w: 24, x: 0, y: 8 }
      )
      .addPanel(
        panels.memoryUsage,
        gridPos={ h: 7, w: 18, x: 0, y: 9 }
      )
      .addPanel(
        panels.memoryUsageGauge,
        gridPos={ h: 7, w: 6, x: 18, y: 9 }
      )
      .addPanel(
        row.new(title='Disk'),
        gridPos={ h: 1, w: 24, x: 0, y: 16 }
      )
      .addPanel(
        panels.diskIO,
        gridPos={ h: 7, w: 12, x: 0, y: 17 }
      )
      .addPanel(
        panels.diskSpaceUsage,
        gridPos={ h: 7, w: 12, x: 12, y: 17 }
      )
      .addPanel(
        row.new(title='Network'),
        gridPos={ h: 1, w: 24, x: 0, y: 24 }
      )
      .addPanel(
        panels.networkReceived,
        gridPos={ h: 7, w: 12, x: 0, y: 25 }
      )
      .addPanel(
        panels.networkTransmitted,
        gridPos={ h: 7, w: 12, x: 12, y: 25 }
      ),
  },
}
