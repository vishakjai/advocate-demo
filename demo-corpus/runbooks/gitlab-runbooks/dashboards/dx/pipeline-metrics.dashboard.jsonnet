local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local template = grafana.template;
local stableIds = import 'stable-ids/stable-ids.libsonnet';

local dashboardDatasource = { type: 'datasource', uid: '-- Dashboard --' };

local projectPathTemplate = template.custom(
  'project_path',
  'gitlab-org/gitlab',
  'gitlab-org/gitlab',
) + { hide: 2 };

local runtimeStatusTemplate = template.custom(
  'runtime_status',
  'success, failed',
  'success',
) + {
  description: 'Status filter for duration dashboards',
  includeAll: true,
};

local aggregationTemplate = template.custom(
  'aggregation',
  'hour,day,week,month',
  'day',
);

(basic.dashboard(
   'Pipeline Metrics',
   tags=config.ciMetricsTags + ['gitlab-org/gitlab'],
   includeEnvironmentTemplate=false,
   includeStandardEnvironmentAnnotations=false,
   includePrometheusDatasourceTemplate=false,
   time_from='now-30d',
   time_to='now',
   uid='dx-pipeline-metrics',
 ) + { timezone: 'browser' })
.addTemplate(projectPathTemplate)
.addTemplate(runtimeStatusTemplate)
.addTemplate(aggregationTemplate)
.addPanel(
  panels.textPanel(|||
    # Pipeline Metrics — gitlab-org/gitlab

    Graphs showing data for pipelines for GitLab project. See [docs](https://docs.gitlab.com/development/pipelines/)

    Pipelines with no tier assigned are mostly documentation change related pipelines that execute a small subset of docs linter jobs

  |||),
  gridPos={ h: 5, w: 24, x: 0, y: 0 },
)
.addPanel(
  (panels.gaugePanel(
     title='Pipeline failure rate',
     rawSql=|||
       SELECT
           toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
           countIf(status = 'failed' AND ref = 'master' AND source = 'push') * 100.0 / nullIf(countIf(ref = 'master' AND source = 'push'), 0) AS master_push,
           countIf(status = 'failed' AND ref = 'master' AND source = 'schedule') * 100.0 / nullIf(countIf(ref = 'master' AND source = 'schedule'), 0) AS master_schedule,
           countIf(status = 'failed' AND source = 'merge_request_event' AND pre_merge_check = false AND tier = 1) * 100.0 / nullIf(countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 1), 0) AS mr_tier_1,
           countIf(status = 'failed' AND source = 'merge_request_event' AND pre_merge_check = false AND tier = 2) * 100.0 / nullIf(countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 2), 0) AS mr_tier_2,
           countIf(status = 'failed' AND source = 'merge_request_event' AND pre_merge_check = false AND tier = 3) * 100.0 / nullIf(countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 3), 0) AS mr_tier_3,
           countIf(status = 'failed' AND source = 'merge_request_event' AND pre_merge_check = false AND tier = 0) * 100.0 / nullIf(countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 0), 0) AS mr_no_tier
       FROM ci_metrics.finished_pipelines_mv
       WHERE
           $__timeFilter(created_at)
           AND project_path = '${project_path}'
           AND original_id = 0
           AND source != 'parent_pipeline'
           AND status != 'canceled'
       GROUP BY time
       ORDER BY time
     |||,
   )) + { stableId: 'failure-rate-per-pipeline-type' },
  gridPos={ h: 13, w: 6, x: 0, y: 5 },
)
.addPanel(
  (panels.timeSeriesPanel(
     title='Pipeline failure rate',
     unit='percent',
   )) {
    datasource: dashboardDatasource,
    targets: [{
      datasource: dashboardDatasource,
      panelId: stableIds.hashStableId('failure-rate-per-pipeline-type'),
      refId: 'A',
    }],
  },
  gridPos={ h: 13, w: 18, x: 6, y: 5 },
)
.addPanel(
  grafana.row.new(title='Duration data', collapse=true)
  .addPanel(
    {
      datasource: panels.clickHouseDatasource,
      fieldConfig: {
        defaults: {
          color: { mode: 'thresholds' },
          custom: {
            align: 'auto',
            cellOptions: { type: 'auto' },
            footer: { reducers: [] },
            inspect: false,
          },
          mappings: [],
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'green', value: 0 },
              { color: 'red', value: 80 },
            ],
          },
        },
        overrides: [
          {
            matcher: { id: 'byName', options: 'duration' },
            properties: [
              { id: 'unit', value: 's' },
            ],
          },
          {
            matcher: { id: 'byName', options: 'pipeline_url' },
            properties: [
              {
                id: 'links',
                value: [
                  {
                    targetBlank: true,
                    title: 'Pipeline URL',
                    url: 'https://pipeline-visualizer-gitlab-org-quality-engineeri-bcf92e4999c4df.gitlab.io/${__value.raw}',
                  },
                ],
              },
            ],
          },
        ],
      },
      options: {
        cellHeight: 'sm',
        enablePagination: true,
        showHeader: true,
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 1,

          pluginVersion: '4.11.4',
          queryType: 'table',
          rawSql: |||
            SELECT
              concat(project_path, '/pipeline/', id) as pipeline_url,
              created_at,
              duration as duration
            FROM ci_metrics.finished_pipelines_mv
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND source = 'merge_request_event'
                AND status IN (${runtime_status:singlequote})
                AND pre_merge_check = false
            ORDER BY duration DESC
            LIMIT 100
          |||,
          refId: 'A',
        },
      ],
      title: 'Slowest pipelines',
      type: 'table',
    },
    gridPos={ h: 9, w: 24, x: 0, y: 32 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='All merge request pipeline duration',
      rawSql=|||
        SELECT
            toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
            avg(duration) AS average,
            quantile(0.95)(duration) AS p95,
            quantile(0.80)(duration) AS p80,
            quantile(0.50)(duration) AS p50
        FROM ci_metrics.finished_pipelines_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND source = 'merge_request_event'
            AND status IN (${runtime_status:singlequote})
            AND pre_merge_check = false
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 13, w: 24, x: 0, y: 41 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='Scheduled master pipeline duration',
      rawSql=|||
        SELECT
            toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
            avg(duration) AS average,
            quantile(0.95)(duration) AS p95,
            quantile(0.80)(duration) AS p80,
            quantile(0.50)(duration) AS p50
        FROM ci_metrics.finished_pipelines_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND source = 'schedule'
            AND ref = 'master'
            AND status IN (${runtime_status:singlequote})
            AND pre_merge_check = false
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 13, w: 24, x: 0, y: 54 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='Tier 1 pipeline duration',
      rawSql=|||
        SELECT
            toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
            avg(duration) AS average,
            quantile(0.95)(duration) AS p95,
            quantile(0.80)(duration) AS p80,
            quantile(0.50)(duration) AS p50
        FROM ci_metrics.finished_pipelines_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND source = 'merge_request_event'
            AND status IN (${runtime_status:singlequote})
            AND tier = 1
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 13, w: 24, x: 0, y: 67 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='Tier 2 pipeline duration',
      rawSql=|||
        SELECT
            toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
            avg(duration) AS average,
            quantile(0.95)(duration) AS p95,
            quantile(0.80)(duration) AS p80,
            quantile(0.50)(duration) AS p50
        FROM ci_metrics.finished_pipelines_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND source = 'merge_request_event'
            AND status IN (${runtime_status:singlequote})
            AND tier = 2
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 13, w: 24, x: 0, y: 80 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='Tier 3 pipeline duration',
      rawSql=|||
        SELECT
            toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
            avg(duration) AS average,
            quantile(0.95)(duration) AS p95,
            quantile(0.80)(duration) AS p80,
            quantile(0.50)(duration) AS p50
        FROM ci_metrics.finished_pipelines_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND source = 'merge_request_event'
            AND status IN (${runtime_status:singlequote})
            AND tier = 3
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 13, w: 24, x: 0, y: 93 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='No tier pipeline duration',
      rawSql=|||
        SELECT
            toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
            avg(duration) AS average,
            quantile(0.95)(duration) AS p95,
            quantile(0.80)(duration) AS p80,
            quantile(0.50)(duration) AS p50
        FROM ci_metrics.finished_pipelines_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND source = 'merge_request_event'
            AND pre_merge_check = false
            AND status IN (${runtime_status:singlequote})
            AND tier = 0
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 13, w: 24, x: 0, y: 106 },
  )
  .addPanel(
    {
      datasource: panels.clickHouseDatasource,
      fieldConfig: {
        defaults: {
          color: { mode: 'palette-classic' },
          custom: {
            axisBorderShow: false,
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: '',
            axisPlacement: 'auto',
            fillOpacity: 80,
            gradientMode: 'none',
            hideFrom: {
              legend: false,
              tooltip: false,
              viz: false,
            },
            lineWidth: 1,
            scaleDistribution: { type: 'linear' },
            thresholdsStyle: { mode: 'off' },
          },
          mappings: [],
          thresholds: {
            mode: 'absolute',
            steps: [
              { color: 'green', value: 0 },
              { color: 'red', value: 80 },
            ],
          },
          unit: 's',
        },
        overrides: [],
      },
      options: {
        barRadius: 0,
        barWidth: 0.97,
        fullHighlight: false,
        groupWidth: 0.7,
        legend: {
          calcs: [],
          displayMode: 'list',
          placement: 'bottom',
          showLegend: true,
        },
        orientation: 'auto',
        showValue: 'always',
        stacking: 'none',
        tooltip: {
          hideZeros: false,
          mode: 'single',
          sort: 'none',
        },
        xTickLabelRotation: 0,
        xTickLabelSpacing: 0,
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          datasource: panels.clickHouseDatasource,
          editorType: 'sql',
          format: 1,
          hide: false,

          pluginVersion: '4.11.4',
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                quantile(0.80)(duration) AS tier_1
            FROM ci_metrics.finished_pipelines_mv
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND source = 'merge_request_event'
                AND status IN (${runtime_status:singlequote})
                AND tier = 1
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'B',
        },
        {
          datasource: panels.clickHouseDatasource,
          editorType: 'sql',
          format: 1,
          hide: false,

          pluginVersion: '4.11.4',
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                quantile(0.80)(duration) AS tier_2
            FROM ci_metrics.finished_pipelines_mv
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND source = 'merge_request_event'
                AND status IN (${runtime_status:singlequote})
                AND tier = 2
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'C',
        },
        {
          editorType: 'sql',
          format: 1,

          pluginVersion: '4.11.4',
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                quantile(0.80)(duration) AS tier_3
            FROM ci_metrics.finished_pipelines_mv
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND source = 'merge_request_event'
                AND status IN (${runtime_status:singlequote})
                AND tier = 3
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
        },
      ],
      title: 'P80 pipeline duration',
      transformations: [{ id: 'merge', options: {} }],
      type: 'barchart',
    },
    gridPos={ h: 13, w: 24, x: 0, y: 119 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 18 },
)
.addPanel(
  grafana.row.new(title='Volume data', collapse=true)
  .addPanel(
    {
      type: 'stat',
      stableId: 'pipelines-per-pipeline-type',
      title: 'Pipeline Count per Pipeline Type',
      datasource: panels.clickHouseDatasource,
      description: 'Total number of pipelines broken down by pipeline type.',
      fieldConfig: {
        defaults: {
          color: { fixedColor: '#95959f', mode: 'fixed' },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
          unit: 'short',
        },
        overrides: [],
      },
      options: {
        colorMode: 'value',
        graphMode: 'none',
        justifyMode: 'center',
        orientation: 'auto',
        percentChangeColorMode: 'inverted',
        reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
        showPercentChange: true,
        textMode: 'auto',
        wideLayout: true,
      },
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                countIf(ref = 'master' AND source = 'push') AS master_push,
                countIf(ref = 'master' AND source = 'schedule') AS master_schedule,
                countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 1) AS mr_tier_1,
                countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 2) AS mr_tier_2,
                countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 3) AS mr_tier_3,
                countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 0) AS mr_no_tier
            FROM ci_metrics.finished_pipelines_mv
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND original_id = 0
                AND source != 'parent_pipeline'
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
        },
      ],
    },
    gridPos={ x: 0, y: 0, w: 6, h: 10 },
  )
  .addPanel(
    (panels.timeSeriesPanel(
       title='Pipeline Count per Pipeline Type',
       unit='short',
       description='Total number of pipelines broken down by pipeline type.',
       legendCalcs=['median', 'mean'],
       legendPlacement='right',
     )) {
      datasource: dashboardDatasource,
      targets: [{
        datasource: dashboardDatasource,
        panelId: stableIds.hashStableId('pipelines-per-pipeline-type'),
        refId: 'A',
      }],
    },
    gridPos={ x: 6, y: 0, w: 18, h: 10 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 19 },
)
.addPanel(
  grafana.row.new(title='Composition data', collapse=true)
  .addPanel(
    panels.textPanel(text='## Pipeline split'),
    gridPos={ x: 0, y: 0, w: 24, h: 2 },
  )
  .addPanel(
    {
      type: 'barchart',
      title: 'Pipeline count by type',
      datasource: panels.clickHouseDatasource,
      description: 'Count of pipelines broken down by pipeline type.',
      fieldConfig: {
        defaults: {
          color: { mode: 'palette-classic' },
          custom: {
            axisBorderShow: false,
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: '',
            axisPlacement: 'auto',
            fillOpacity: 80,
            gradientMode: 'none',
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineWidth: 1,
            scaleDistribution: { type: 'linear' },
            thresholdsStyle: { mode: 'off' },
          },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
          unit: 'short',
        },
        overrides: [],
      },
      options: {
        barRadius: 0,
        barWidth: 0.97,
        fullHighlight: false,
        groupWidth: 0.7,
        legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
        orientation: 'auto',
        showValue: 'auto',
        stacking: 'percent',
        tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
        xTickLabelRotation: 0,
        xTickLabelSpacing: 0,
      },
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                countIf(ref = 'master' AND source = 'push') AS master_push,
                countIf(ref = 'master' AND source = 'schedule') AS master_schedule,
                countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 1) AS mr_tier_1,
                countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 2) AS mr_tier_2,
                countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 3) AS mr_tier_3,
                countIf(source = 'merge_request_event' AND pre_merge_check = false AND tier = 0) AS mr_no_tier
            FROM ci_metrics.finished_pipelines_mv
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND original_id = 0
                AND source != 'parent_pipeline'
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
        },
      ],
    },
    gridPos={ x: 0, y: 2, w: 24, h: 10 },
  )
  .addPanel(
    panels.textPanel(text='## MR pipeline split'),
    gridPos={ x: 0, y: 12, w: 24, h: 2 },
  )
  .addPanel(
    {
      type: 'barchart',
      title: 'MR pipelines: draft vs non-draft',
      datasource: panels.clickHouseDatasource,
      description: 'Distribution of MR pipelines triggered from draft vs non-draft merge requests.',
      fieldConfig: {
        defaults: {
          color: { mode: 'palette-classic' },
          custom: {
            axisBorderShow: false,
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: '',
            axisPlacement: 'auto',
            fillOpacity: 80,
            gradientMode: 'none',
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineWidth: 1,
            scaleDistribution: { type: 'linear' },
            thresholdsStyle: { mode: 'off' },
          },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
          unit: 'short',
        },
        overrides: [],
      },
      options: {
        barRadius: 0,
        barWidth: 0.97,
        fullHighlight: false,
        groupWidth: 0.7,
        legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
        orientation: 'auto',
        showValue: 'auto',
        stacking: 'percent',
        tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
        xTickLabelRotation: 0,
        xTickLabelSpacing: 0,
      },
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                countIf(mr_in_draft = true) AS draft,
                countIf(mr_in_draft = false) AS non_draft
            FROM ci_metrics.pipeline_metrics
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND source = 'merge_request_event'
                AND mr_iid != 0
                AND status IN ('success', 'failed')
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
        },
      ],
    },
    gridPos={ x: 0, y: 14, w: 24, h: 10 },
  )
  .addPanel(
    {
      type: 'barchart',
      title: 'Non-draft MR tier composition',
      datasource: panels.clickHouseDatasource,
      description: 'Tier distribution of MR pipelines from non-draft merge requests.',
      fieldConfig: {
        defaults: {
          color: { mode: 'palette-classic' },
          custom: {
            axisBorderShow: false,
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: '',
            axisPlacement: 'auto',
            fillOpacity: 80,
            gradientMode: 'none',
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineWidth: 1,
            scaleDistribution: { type: 'linear' },
            thresholdsStyle: { mode: 'off' },
          },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
          unit: 'short',
        },
        overrides: [],
      },
      options: {
        barRadius: 0,
        barWidth: 0.97,
        fullHighlight: false,
        groupWidth: 0.7,
        legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
        orientation: 'auto',
        showValue: 'auto',
        stacking: 'percent',
        tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
        xTickLabelRotation: 0,
        xTickLabelSpacing: 0,
      },
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                countIf(tier = 1) AS tier_1,
                countIf(tier = 2) AS tier_2,
                countIf(tier = 3) AS tier_3,
                countIf(tier = 0) AS no_tier
            FROM ci_metrics.pipeline_metrics
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND source = 'merge_request_event'
                AND mr_iid != 0
                AND mr_in_draft = false
                AND status IN ('success', 'failed')
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
        },
      ],
    },
    gridPos={ x: 0, y: 24, w: 12, h: 10 },
  )
  .addPanel(
    {
      type: 'barchart',
      title: 'Draft MR tier composition',
      datasource: panels.clickHouseDatasource,
      description: 'Tier distribution of MR pipelines from draft merge requests.',
      fieldConfig: {
        defaults: {
          color: { mode: 'palette-classic' },
          custom: {
            axisBorderShow: false,
            axisCenteredZero: false,
            axisColorMode: 'text',
            axisLabel: '',
            axisPlacement: 'auto',
            fillOpacity: 80,
            gradientMode: 'none',
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineWidth: 1,
            scaleDistribution: { type: 'linear' },
            thresholdsStyle: { mode: 'off' },
          },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
          unit: 'short',
        },
        overrides: [],
      },
      options: {
        barRadius: 0,
        barWidth: 0.97,
        fullHighlight: false,
        groupWidth: 0.7,
        legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true },
        orientation: 'auto',
        showValue: 'auto',
        stacking: 'percent',
        tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
        xTickLabelRotation: 0,
        xTickLabelSpacing: 0,
      },
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                countIf(tier = 1) AS tier_1,
                countIf(tier = 2) AS tier_2,
                countIf(tier = 3) AS tier_3,
                countIf(tier = 0) AS no_tier
            FROM ci_metrics.pipeline_metrics
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND source = 'merge_request_event'
                AND mr_iid != 0
                AND mr_in_draft = true
                AND status IN ('success', 'failed')
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
        },
      ],
    },
    gridPos={ x: 12, y: 24, w: 12, h: 10 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 20 },
)
.addPanel(
  grafana.row.new(title='Cost data', collapse=true)
  .addPanel(
    {
      type: 'stat',
      stableId: 'cost-per-pipeline-type',
      title: 'Cost per Pipeline Type',
      datasource: panels.clickHouseDatasource,
      description: 'Average cost per single pipeline broken down by pipeline type.',
      fieldConfig: {
        defaults: {
          color: { fixedColor: '#95959f', mode: 'fixed' },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
          unit: 'currencyUSD',
        },
        overrides: [],
      },
      options: {
        colorMode: 'value',
        graphMode: 'none',
        justifyMode: 'center',
        orientation: 'auto',
        percentChangeColorMode: 'inverted',
        reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
        showPercentChange: true,
        textMode: 'auto',
        wideLayout: true,
      },
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,
                avgIf(cost, ref = 'master' AND source = 'push') AS master_push,
                avgIf(cost, ref = 'master' AND source = 'schedule') AS master_schedule,
                avgIf(cost, mr_iid != 0 AND tier = 1) AS mr_tier_1,
                avgIf(cost, mr_iid != 0 AND tier = 2) AS mr_tier_2,
                avgIf(cost, mr_iid != 0 AND tier = 3) AS mr_tier_3,
                avgIf(cost, mr_iid != 0 AND tier = 0) AS mr_no_tier
            FROM ci_metrics.pipeline_costs FINAL
            WHERE
                $__timeFilter(created_at)
                AND project_path = '${project_path}'
                AND original_id = 0
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
        },
      ],
    },
    gridPos={ x: 0, y: 0, w: 6, h: 10 },
  )
  .addPanel(
    (panels.timeSeriesPanel(
       title='Cost per Pipeline Type',
       unit='currencyUSD',
       description='Average cost per single pipeline broken down by pipeline type.',
       legendCalcs=['median', 'mean'],
       legendPlacement='right',
     )) {
      datasource: dashboardDatasource,
      targets: [{
        datasource: dashboardDatasource,
        panelId: stableIds.hashStableId('cost-per-pipeline-type'),
        refId: 'A',
      }],
    },
    gridPos={ x: 6, y: 0, w: 18, h: 10 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 21 },
)
.addPanel(
  grafana.row.new(title='Job data', collapse=true)
  .addPanel(
    {
      type: 'stat',
      stableId: 'jobs-per-pipeline-type',
      title: 'Job Count per Pipeline Type',
      datasource: panels.clickHouseDatasource,
      description: 'Average number of jobs per single pipeline broken down by pipeline type.',
      fieldConfig: {
        defaults: {
          color: { fixedColor: '#95959f', mode: 'fixed' },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
          unit: 'short',
        },
        overrides: [],
      },
      options: {
        colorMode: 'value',
        graphMode: 'none',
        justifyMode: 'center',
        orientation: 'auto',
        percentChangeColorMode: 'inverted',
        reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
        showPercentChange: true,
        textMode: 'auto',
        wideLayout: true,
      },
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,
                avgIf(builds, ref = 'master' AND source = 'push') AS master_push,
                avgIf(builds, ref = 'master' AND source = 'schedule') AS master_schedule,
                avgIf(builds, source = 'merge_request_event' AND pre_merge_check = false AND tier = 1) AS mr_tier_1,
                avgIf(builds, source = 'merge_request_event' AND pre_merge_check = false AND tier = 2) AS mr_tier_2,
                avgIf(builds, source = 'merge_request_event' AND pre_merge_check = false AND tier = 3) AS mr_tier_3,
                avgIf(builds, source = 'merge_request_event' AND pre_merge_check = false AND tier = 0) AS mr_no_tier
            FROM (
                SELECT
                    id,
                    min(created_at) AS timestamp,
                    sum(total_builds) AS builds,
                    argMin(ref, original_id) AS ref,
                    argMin(source, original_id) AS source,
                    argMin(tier, original_id) AS tier,
                    min(pre_merge_check) AS pre_merge_check
                FROM ci_metrics.finished_pipelines_mv
                WHERE
                    $__timeFilter(created_at)
                    AND project_path = '${project_path}'
                GROUP BY id
            )
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
        },
      ],
    },
    gridPos={ x: 0, y: 0, w: 6, h: 10 },
  )
  .addPanel(
    (panels.timeSeriesPanel(
       title='Job Count per Pipeline Type',
       unit='short',
       description='Average number of jobs per single pipeline broken down by pipeline type.',
       legendCalcs=['median', 'mean'],
       legendPlacement='right',
     )) {
      datasource: dashboardDatasource,
      targets: [{
        datasource: dashboardDatasource,
        panelId: stableIds.hashStableId('jobs-per-pipeline-type'),
        refId: 'A',
      }],
    },
    gridPos={ x: 6, y: 0, w: 18, h: 10 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 22 },
)
.trailer()
