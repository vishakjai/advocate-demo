local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';

local template = grafana.template;
local metadata = ['flow_type', 'grpc_method', 'lsp_version', 'gitlab_version', 'client_type', 'gitlab_realm'];

local createTemplate(name) = template.new(
  name,
  '$PROMETHEUS_DS',
  query='label_values(grpc_server_handled_total{type="duo-workflow-svc"}, ' + name + ')',
  current='.*',
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
  allValues='.*',
);

local baseFilters = 'env="$environment",type="duo-workflow-svc",grpc_method=~"$grpc_method",lsp_version=~"$lsp_version",gitlab_version=~"$gitlab_version",flow_type=~"$flow_type",client_type=~"$client_type"';

// Creates a panel showing success/error ratio, optionally broken down by a dimension
local createErrorRatioPanel(breakdownBy=null) =
  local groupByLabels = if breakdownBy != null then 'grpc_code,' + breakdownBy else 'grpc_code';
  local titleSuffix = if breakdownBy != null then ' by ' + breakdownBy else '';

  panel.timeSeries(
    title='Success/Error ratio' + titleSuffix + ' (%)',
    description='All gRPC status codes for ExecuteWorkflow streams' + titleSuffix + ' as a percentage of all streams. OK means success and others are error types. Will add up to 100.',
    datasource=mimirHelper.mimirDatasource('runway'),
    stack=true,
    fill=100,
    query=|||
      sum by (%(groupBy)s) (
        sli_aggregations:grpc_server_handled_total:rate_5m{%(filters)s}
      )
      / ignoring(%(groupBy)s) group_left
      sum(
        sli_aggregations:grpc_server_handled_total:rate_5m{%(filters)s}
      ) * 100
    ||| % {
      filters: baseFilters,
      groupBy: groupByLabels,
    },
  );

local templates = [createTemplate(name) for name in metadata];

// Create panels: 1 overall + 1 for each metadata dimension
local panels = [createErrorRatioPanel()] + [createErrorRatioPanel(dim) for dim in metadata];

basic.dashboard(
  'Duo Workflow Service Error Breakdown',
  tags=[],
  includeEnvironmentTemplate=true,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=mimirHelper.mimirDatasource('runway'),
)
.addTemplates(templates)
.addPanels(layout.grid(panels, cols=2, rowHeight=12))
