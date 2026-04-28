local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local colorScheme = import 'grafana/color_scheme.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';

local text = grafana.text;
local template = grafana.template;


local tissueStatPanel(title, patch_status, colorZero, colorOne) =
  basic.statPanel(
    panelTitle=title,
    title='',
    color=[
      { color: colorZero, value: null },
      { color: colorOne, value: 1 },
    ],
    query=|||
      sum by (ring) (
        last_over_time(
          delivery_tissue_patches_queued_current{
            amp="$amp_environment",
            patch_status="%s"
          }[$__rate_interval]
        )
      )
    ||| % [patch_status],
    legendFormat='Ring {{ring}}',
    description="The current number of patches by ring in the '%s' status" % [patch_status],
    min=0,
    max=1,
    instant=false,
    colorMode='value',
    graphMode='area',
    orientation='horizontal',
  );

basic.dashboard(
  'Tissue - Ring Deployments',
  tags=['delivery'],
  time_from='now-24h',
  time_to='now',
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-ops'),
)

.addTemplate(
  template.new(
    'amp_environment',
    '$PROMETHEUS_DS',
    'label_values(delivery_tissue_patches_queued_current,amp)',
    current='cellsdev',
    refresh='load',
    sort=1,
  )
)

.addPanel(
  text.new(
    title='Cells Deployments Dashboard',
    mode='markdown',
    content=|||
      GitLab Cells deployments are managed by 🧫 Tissue.

      [List of deployment pipelines](https://ops.gitlab.net/gitlab-com/gl-infra/cells/tissue/-/pipelines?scope=all&source=api).
    |||
  ),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 3,
  },
)

.addPanels(layout.grid([
  tissueStatPanel('In rollout patches', 'in rollout', colorScheme.warningColor, colorScheme.normalRangeColor),
  basic.statPanel(
    panelTitle='Processed patches',
    title='',
    color=[
      { color: colorScheme.criticalColor, value: null },
      { color: colorScheme.normalRangeColor, value: 1 },
    ],
    query=|||
      sum(increase(delivery_tissue_patches_processed_total{amp="$amp_environment"}[$__range])) by (amp, ring)
    |||,
    legendFormat='Ring {{ring}}',
    description='The current number of patches processed by each ring',
    min=0,
    orientation='horizontal',
  ),
  panel.timeSeries(
    title='Pending / Paused patches',
    query=|||
      sum by (ring, patch_status) (
        last_over_time(
          delivery_tissue_patches_queued_current{
            amp="$amp_environment",
            patch_status=~"pending|paused"
          }[$__rate_interval]
        )
      )
    |||,
    legendFormat='ring {{ring}} - {{patch_status}}',
  ),
  tissueStatPanel('Failed patches', 'failed', colorScheme.normalRangeColor, colorScheme.criticalColor),
], cols=2, rowHeight=10))

.trailer()
