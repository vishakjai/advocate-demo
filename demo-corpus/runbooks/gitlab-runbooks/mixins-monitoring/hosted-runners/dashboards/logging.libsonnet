local grafana = import 'grafonnet/grafana.libsonnet';
local basic = import 'runbooks/libsonnet/grafana/basic.libsonnet';
local layout = import 'runbooks/libsonnet/grafana/layout.libsonnet';

local fluentdPanels = import './panels/fluentd.libsonnet';
local replicationPanels = import './panels/replications.libsonnet';
local runnerPanels = import './panels/runner.libsonnet';


local row = grafana.row;

{
  _fluentdPluginTemplate:: $._config.templates.fluentdPlugin,

  _fluentdPanels:: fluentdPanels.new($._config.fluentdPluginSelector),

  _replicationPanels:: replicationPanels.new($._config.replicationSelector),

  grafanaDashboards+:: {
    'hosted-runners-logging.json':
      basic.dashboard(
        title='%s Logging' % $._config.dashboardName,
        tags=$._config.dashboardTags,
        editable=true,
        includeStandardEnvironmentAnnotations=false,
        includeEnvironmentTemplate=false,
        defaultDatasource=$._config.prometheusDatasource
      ).addTemplate($._config.templates.stackSelector)
      .addTemplate($._config.templates.shardSelector)
      .addTemplate($._fluentdPluginTemplate)
      .addPanels(
        runnerPanels.headlineMetricsRow(
          rowTitle='Hosted Runner(s) Logging Overview',
          serviceType='hosted-runners-logging',
          metricsCatalogServiceInfo=$._config.gitlabMetricsConfig.monitoredServices[1],
          selectorHash={ component: 'usage_logs' },
          showSaturationCell=false
        )
      ).addPanel(
        row.new(title='Fluentd Operations'),
        gridPos={ x: 0, y: 1000, w: 24, h: 1 }
      ).addPanels(layout.grid([
        $._fluentdPanels.emitRecords,
        $._fluentdPanels.retryWait,
        $._fluentdPanels.writeCounts,
        $._fluentdPanels.errorAndRetryRate,
        $._fluentdPanels.outputFlushTime,
        $._fluentdPanels.bufferLength,
        $._fluentdPanels.bufferTotalSize,
        $._fluentdPanels.bufferFreeSpace,
      ], cols=4, rowHeight=8, startRow=1001))
      .addPanel(
        row.new(title='Replication Metrics'),
        gridPos={ x: 0, y: 2000, w: 24, h: 1 }
      ).addPanels(layout.grid([
        $._replicationPanels.pendingOperations($._config.replicationSelector),
        $._replicationPanels.latency($._config.replicationSelector),
        $._replicationPanels.bytesPending($._config.replicationSelector),
        $._replicationPanels.operationsFailed($._config.replicationSelector),
      ], cols=4, rowHeight=8, startRow=2001)),
  },
}
