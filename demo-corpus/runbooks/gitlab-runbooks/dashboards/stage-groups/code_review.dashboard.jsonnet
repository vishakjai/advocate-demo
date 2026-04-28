local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local stageGroupDashboards = import './stage-group-dashboards.libsonnet';

local diffsDurations(title, description, metricName) =
  local quantileQuery(quantile) = |||
    histogram_quantile(
          %(quantile)f,
          sum(
            rate(%(metricName)s{environment="$environment", stage="$stage"}[$__interval])
          ) by (le)
        )
  ||| % {
    quantile: quantile,
    metricName: metricName,
  };
  panel.multiTimeSeries(
    title=title,
    format='short',
    yAxisLabel='',
    description=description,
    queries=[{
      query: quantileQuery(0.50),
      legendFormat: 'Average',
    }, {
      query: quantileQuery(0.90),
      legendFormat: '90th Percentile',
    }]
  );

local diffsAvgRenderingDuration() =
  diffsDurations(
    'Rendering Time',
    'Duration spent on serializing and rendering diffs on diffs batch request',
    'gitlab_diffs_render_real_duration_seconds_bucket'
  );

local diffsAvgReorderDuration() =
  diffsDurations(
    'Reordering Time',
    'Duration spent on reordering of diff files on diffs batch request',
    'gitlab_diffs_reorder_real_duration_seconds_bucket'
  );

local diffsAvgCollectionDuration() =
  diffsDurations(
    'Collection Time',
    'Duration spent on querying merge request diff files on diffs batch request',
    'gitlab_diffs_collection_real_duration_seconds_bucket'
  );

local diffsAvgComparisonDuration() =
  diffsDurations(
    'Comparison Time',
    'Duration spent on getting comparison data on diffs batch request',
    'gitlab_diffs_comparison_real_duration_seconds_bucket'
  );

local diffsAvgUnfoldablePositionsDuration() =
  diffsDurations(
    'Unfoldable Positions Time',
    'Duration spent on getting unfoldable note positions on diffs batch request',
    'gitlab_diffs_unfoldable_positions_real_duration_seconds_bucket'
  );

local diffsAvgUnfoldDuration() =
  diffsDurations(
    'Unfold Time',
    'Duration spent on unfolding positions on diffs batch request',
    'gitlab_diffs_unfold_real_duration_seconds_bucket'
  );

local diffsAvgWriteCacheDuration() =
  diffsDurations(
    'Write Cache Time',
    'Duration spent on caching highlighted lines and stats on diffs batch request',
    'gitlab_diffs_write_cache_real_duration_seconds_bucket'
  );

local diffsAvgHighlightCacheDecorateDuration() =
  diffsDurations(
    'Highlight Cache Decorate Time',
    'Duration spent on setting highlighted lines from cache on diffs batch request',
    'gitlab_diffs_highlight_cache_decorate_real_duration_seconds_bucket'
  );

stageGroupDashboards.dashboard('code_review')
.addPanels(
  layout.titleRowWithPanels(
    'diffs_batch.json Metrics',
    layout.grid(
      [
        diffsAvgRenderingDuration(),
        diffsAvgReorderDuration(),
        diffsAvgCollectionDuration(),
        diffsAvgComparisonDuration(),
        diffsAvgUnfoldablePositionsDuration(),
        diffsAvgUnfoldDuration(),
        diffsAvgWriteCacheDuration(),
        diffsAvgHighlightCacheDecorateDuration(),
      ],
      cols=4,
      startRow=1002
    ),
    collapse=false,
    startRow=1001
  ),
)
.stageGroupDashboardTrailer()
