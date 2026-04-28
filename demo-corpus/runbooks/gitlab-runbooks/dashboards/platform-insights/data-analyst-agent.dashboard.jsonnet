local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local template = grafana.template;
local statPanel = grafana.statPanel;
local promQuery = import 'grafana/prom_query.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';

/* This dashboard uses both $PROMETHEUS_DS and a hardcoded runway datasource.
 *
 * The GLQL API SLIs row uses $PROMETHEUS_DS which can be toggled between environments
 * (typically mimir-gitlab-gprd or mimir-gitlab-gstg).
 *
 * The Data Agent SLIs row uses the hardcoded mimir-runway datasource since those
 * metrics are only available in the runway tenant.
 */

local runwayMimirDatasourceUid = mimirHelper.mimirDatasource('runway');

local runwayMultiSelectTemplate(name, metricLabel) =
  template.new(
    name=name,
    datasource=runwayMimirDatasourceUid,
    query='label_values(grpc_server_handled_total{type="duo-workflow-svc"}, ' + metricLabel + ')',
    refresh='on_time_interval',
    includeAll=true,
    allValues='.*',
    multi=true,
    sort=true,
  );

local grpcSelectorBase = {
  env: '$environment',
  stage: '$stage',
  type: 'duo-workflow-svc',
};

local grpcSelectorFull = grpcSelectorBase {
  grpc_method: '$grpc_method',
  lsp_version: '$lsp_version',
  gitlab_version: '$gitlab_version',
  flow_type: '$flow_type',
  client_type: '$client_type',
};

local grpcQuery(extraFilters='') =
  'env="$environment",stage="$stage",type="duo-workflow-svc",grpc_method=~"$grpc_method",lsp_version=~"$lsp_version",gitlab_version=~"$gitlab_version",flow_type=~"$flow_type",client_type=~"$client_type"' + extraFilters;

local glqlSelector = {
  env: '$environment',
  job: 'gitlab-rails',
  stage: '$stage',
};

local glqlQuery = 'endpoint_id=~".*/api/:version/glql",env="$environment",job="gitlab-rails",stage="$stage"';

local barChart(title, query, legendFormat='', datasource='$PROMETHEUS_DS') = {
  type: 'barchart',
  title: title,
  datasource: datasource,
  targets: [{
    expr: query,
    legendFormat: legendFormat,
    refId: 'A',
    editorMode: 'code',
    range: true,
  }],
};

local environmentTemplate = template.custom(
  name='environment',
  query='gprd,gstg',
  refresh='on_time_interval',
  includeAll=false,
  current='gprd',
);

local flowTypeTemplate = template.new(
  name='flow_type',
  datasource=runwayMimirDatasourceUid,
  query='label_values(grpc_server_handled_total{type="duo-workflow-svc"}, flow_type)',
  refresh='on_time_interval',
  includeAll=false,
  current='analytics_agent/v1',
  label='Flow Type',
);

local grpcMethodTemplate = runwayMultiSelectTemplate('grpc_method', 'grpc_method');
local lspVersionTemplate = runwayMultiSelectTemplate('lsp_version', 'lsp_version');
local gitlabVersionTemplate = runwayMultiSelectTemplate('gitlab_version', 'gitlab_version');
local clientTypeTemplate = runwayMultiSelectTemplate('client_type', 'client_type');
local gitlabRealmTemplate = runwayMultiSelectTemplate('gitlab_realm', 'gitlab_realm');

local glqlThroughputPanel =
  panel.timeSeries(
    title='GLQL Throughput (RPS)',
    query='sum(sli_aggregations:gitlab_sli_rails_request_total:rate_5m{' + glqlQuery + '})',
    legendFormat='Throughput',
    datasource='$PROMETHEUS_DS',
  );

local glqlSuccessRatePanel =
  statPanel.new(
    title='GLQL Success Rate (%)',
    datasource='$PROMETHEUS_DS',
    reducerFunction='lastNotNull',
    graphMode='area',
    colorMode='value',
    unit='percent',
  )
  .addThreshold({ color: 'red', value: null })
  .addThreshold({ color: 'green', value: 80 })
  .addTarget(
    promQuery.target(
      '(sum(sli_aggregations:gitlab_sli_rails_request_total:rate_5m{' + glqlQuery + ', status!~"[4|5].."}) / sum(sli_aggregations:gitlab_sli_rails_request_total:rate_5m{' + glqlQuery + '})) * 100',
      legendFormat='Success Rate',
    )
  );

local glqlErrorsPanel =
  barChart(
    'GLQL Errors (RPS)',
    'sum(sli_aggregations:gitlab_sli_rails_request_error_total:rate_5m{' + glqlQuery + '})',
    legendFormat='Errors',
    datasource='$PROMETHEUS_DS',
  );

local glqlErrorRatioPanel =
  panel.timeSeries(
    title='GLQL Error Ratio (%)',
    description='Error rates are a measure of unhandled service exceptions per second. Client errors are excluded when possible. Lower is better',
    query='(sum(sli_aggregations:gitlab_sli_rails_request_error_total:rate_5m{' + glqlQuery + '}) / sum(sli_aggregations:gitlab_sli_rails_request_total:rate_5m{' + glqlQuery + '})) * 100',
    legendFormat='Error Ratio',
    yAxisLabel='Error %',
    linewidth=2,
    datasource='$PROMETHEUS_DS',
  )
  .addDataLink({
    url: 'https://dashboards.gitlab.net/d/api-rails-controller/api-detail?${__url_time_range}&${__all_variables}&var-controller=Gitlab::Glql::QueriesController',
    title: 'GitLab GLQL API Dashboard',
    targetBlank: true,
  });

local dataAgentSuccessErrorPanel =
  panel.timeSeries(
    title='server success/error ratio - per grpc_code',
    query='sum by (grpc_code) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_code!=""') + '}) > 0',
    legendFormat='{{grpc_code}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentErrorsByCodePanel =
  panel.timeSeries(
    title='server errors - per grpc_code',
    query='sum by (grpc_code) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_code!~"OK",grpc_code!=""') + '}) > 0',
    legendFormat='{{grpc_code}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentRpsByCodePanel =
  panel.timeSeries(
    title='server RPS - per grpc_code',
    query='sum by (grpc_code) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_code!=""') + '}) > 0',
    legendFormat='{{grpc_code}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentErrorsByMethodPanel =
  panel.timeSeries(
    title='server errors - per grpc_method',
    query='sum by (grpc_method) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_code!~"OK",grpc_method!=""') + '}) > 0',
    legendFormat='{{grpc_method}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentRpsByMethodPanel =
  panel.timeSeries(
    title='server RPS - per grpc_method',
    query='sum by (grpc_method) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_method!=""') + '}) > 0',
    legendFormat='{{grpc_method}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentSuccessErrorByLspVersionPanel =
  panel.timeSeries(
    title='server success/error ratio - per lsp_version',
    query='sum by (lsp_version) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',lsp_version!=""') + '}) > 0',
    legendFormat='{{lsp_version}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentErrorsByServicePanel =
  panel.timeSeries(
    title='server errors - per grpc_service',
    query='sum by (grpc_service) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_code!~"OK",grpc_service!=""') + '}) > 0',
    legendFormat='{{grpc_service}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentRpsByServicePanel =
  panel.timeSeries(
    title='server RPS - per grpc_service',
    query='sum by (grpc_service) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_service!=""') + '}) > 0',
    legendFormat='{{grpc_service}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentSuccessErrorByClientTypePanel =
  panel.timeSeries(
    title='server success/error ratio - per client_type',
    query='sum by (client_type) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',client_type!=""') + '}) > 0',
    legendFormat='{{client_type}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentErrorsByTypePanel =
  panel.timeSeries(
    title='server errors - per grpc_type',
    query='sum by (grpc_type) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_code!~"OK",grpc_type!=""') + '}) > 0',
    legendFormat='{{grpc_type}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentRpsByTypePanel =
  panel.timeSeries(
    title='server RPS - per grpc_type',
    query='sum by (grpc_type) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_type!=""') + '}) > 0',
    legendFormat='{{grpc_type}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentSuccessErrorByRealmPanel =
  panel.timeSeries(
    title='server success/error ratio - per gitlab_realm',
    query='sum by (gitlab_realm) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',gitlab_realm!=""') + '}) > 0',
    legendFormat='{{gitlab_realm}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentSuccessErrorByMethodPanel =
  panel.timeSeries(
    title='server success/error ratio - per grpc_method',
    query='sum by (grpc_method) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',grpc_method!=""') + '}) > 0',
    legendFormat='{{grpc_method}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

local dataAgentSuccessErrorByVersionPanel =
  panel.timeSeries(
    title='server success/error ratio - per gitlab_version',
    query='sum by (gitlab_version) (sli_aggregations:grpc_server_handled_total:rate_5m{' + grpcQuery(',gitlab_version!=""') + '}) > 0',
    legendFormat='{{gitlab_version}}',
    fill=50,
    stack=true,
  ) + {
    datasource: { type: 'prometheus', uid: runwayMimirDatasourceUid },
  };

basic.dashboard(
  'Data Analyst Agent',
  tags=['platform-insights', 'glql', 'data-analyst-agent'],
  time_from='now-30d',
  time_to='now',
  includeEnvironmentTemplate=false,
  defaultDatasource='mimir-gitlab-gprd',
)
.addTemplates([
  templates.stage,
  environmentTemplate,
  flowTypeTemplate,
  grpcMethodTemplate,
  lspVersionTemplate,
  gitlabVersionTemplate,
  clientTypeTemplate,
  gitlabRealmTemplate,
])
.addPanels(
  layout.rowGrid(
    'GLQL API SLIs',
    layout.grid(
      [
        glqlThroughputPanel,
        glqlSuccessRatePanel,
        glqlErrorsPanel,
      ],
      cols=3,
      rowHeight=8,
      startRow=1
    ) +
    [
      glqlErrorRatioPanel {
        gridPos: { x: 0, y: 9, w: 24, h: 10 },
      },
    ],
    startRow=0
  ) +
  layout.titleRowWithPanels(
    'Data Agent SLIs',
    [
      dataAgentSuccessErrorPanel {
        gridPos: { x: 0, y: 20, w: 12, h: 12 },
      },
      dataAgentErrorsByCodePanel {
        gridPos: { x: 12, y: 20, w: 6, h: 10 },
      },
      dataAgentRpsByCodePanel {
        gridPos: { x: 18, y: 20, w: 6, h: 10 },
      },
      dataAgentErrorsByMethodPanel {
        gridPos: { x: 12, y: 30, w: 6, h: 10 },
      },
      dataAgentRpsByMethodPanel {
        gridPos: { x: 18, y: 30, w: 6, h: 10 },
      },
      dataAgentSuccessErrorByLspVersionPanel {
        gridPos: { x: 0, y: 32, w: 12, h: 12 },
      },
      dataAgentErrorsByServicePanel {
        gridPos: { x: 12, y: 40, w: 6, h: 10 },
      },
      dataAgentRpsByServicePanel {
        gridPos: { x: 18, y: 40, w: 6, h: 10 },
      },
      dataAgentSuccessErrorByClientTypePanel {
        gridPos: { x: 0, y: 44, w: 12, h: 12 },
      },
      dataAgentErrorsByTypePanel {
        gridPos: { x: 12, y: 50, w: 6, h: 10 },
      },
      dataAgentRpsByTypePanel {
        gridPos: { x: 18, y: 50, w: 6, h: 10 },
      },
      dataAgentSuccessErrorByRealmPanel {
        gridPos: { x: 0, y: 56, w: 12, h: 12 },
      },
      dataAgentSuccessErrorByMethodPanel {
        gridPos: { x: 12, y: 60, w: 12, h: 12 },
      },
      dataAgentSuccessErrorByVersionPanel {
        gridPos: { x: 0, y: 68, w: 12, h: 12 },
      },
    ],
    collapse=false,
    startRow=19
  )
)
+ {
  // Disable deploy annotation by default
  annotations+: {
    list: std.map(
      function(a) if a.name == 'deploy' then a { enable: false } else a,
      super.list
    ),
  },
}
