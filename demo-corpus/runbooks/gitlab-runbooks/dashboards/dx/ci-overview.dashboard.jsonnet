local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;

(basic.dashboard(
   title='CI Overview',
   tags=config.ciMetricsTags,
   time_from='now-30d',
   time_to='now',
   includeEnvironmentTemplate=false,
   includeStandardEnvironmentAnnotations=false,
   includePrometheusDatasourceTemplate=false,
   uid='ci-overview',
 ) + { timezone: 'browser' })
.addTemplate(
  template.new(
    'project_path',
    panels.clickHouseDatasource,
    'SELECT DISTINCT project_path\nFROM ci_metrics.pipeline_metrics\nWHERE created_at >= $__fromTime\n  AND created_at <= $__toTime\nORDER BY project_path',
    current='gitlab-org/gitlab',
    includeAll=false,
  ),
)
.addTemplate(
  template.custom(
    'aggregation',
    'hour,day,week,month',
    'week',
  ),
)
.addPanel(
  row.new(title='Failure rate and count data', collapse=false),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanel(
  {
    type: 'timeseries',
    title: 'Pipeline Failure Rate',
    datasource: panels.clickHouseDatasource,
    description: 'Daily pipeline failure rates',
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisCenteredZero: false,
          axisColorMode: 'text',
          axisLabel: '',
          axisPlacement: 'auto',
          barAlignment: 0,
          barWidthFactor: 0.6,
          drawStyle: 'line',
          fillOpacity: 0,
          gradientMode: 'none',
          hideFrom: { legend: false, tooltip: false, viz: false },
          insertNulls: false,
          lineInterpolation: 'linear',
          lineWidth: 1,
          pointSize: 5,
          scaleDistribution: { type: 'linear' },
          showPoints: 'auto',
          showValues: false,
          spanNulls: true,
          stacking: { group: 'A', mode: 'none' },
          thresholdsStyle: { mode: 'off' },
        },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
        unit: 'percent',
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'mr_train' },
          properties: [{ id: 'color', value: { fixedColor: 'blue', mode: 'fixed' } }],
        },
        {
          matcher: { id: 'byName', options: 'master' },
          properties: [{ id: 'color', value: { fixedColor: 'yellow', mode: 'fixed' } }],
        },
        {
          matcher: { id: 'byName', options: 'master_push' },
          properties: [{ id: 'color', value: { fixedColor: 'yellow', mode: 'fixed' } }],
        },
        {
          matcher: { id: 'byName', options: 'master_schedule' },
          properties: [{ id: 'color', value: { fixedColor: 'purple', mode: 'fixed' } }],
        },
      ],
    },
    options: {
      legend: { calcs: ['median', 'mean'], displayMode: 'table', placement: 'right', showLegend: true },
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
    },
    targets: [
      {
        datasource: panels.clickHouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    countIf(status = 'failed' and pre_merge_check = false) * 100.0 / nullIf(countIf(pre_merge_check = false), 0) AS mr,\n    countIf(status = 'failed' and pre_merge_check = true) * 100.0 / nullIf(countIf(pre_merge_check = true), 0) AS mr_train\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND source != 'parent_pipeline'\n    AND status != 'canceled'\n    AND is_merge_request = true\nGROUP BY time\nORDER BY time",
        refId: 'A',
      },
      {
        datasource: panels.clickHouseDatasource,
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    countIf(source = 'push' AND status = 'failed') * 100.0 / nullIf(countIf(source = 'push'), 0) AS master_push,\n    countIf(source = 'schedule' AND status = 'failed') * 100.0 / nullIf(countIf(source = 'schedule'), 0) AS master_schedule\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND source != 'parent_pipeline'\n    AND status != 'canceled'\n    AND ref = 'master'\nGROUP BY time\nORDER BY time",
        refId: 'B',
      },
    ],
    transformations: [
      {
        id: 'renameByRegex',
        options: {},
      },
    ],
  },
  gridPos={ x: 0, y: 1, w: 24, h: 9 },
)
.addPanel(
  panels.timeSeriesPanel(
    'Total Pipeline Counts',
    "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    countIf(is_merge_request = true AND pre_merge_check = false) AS mr,\n    countIf(is_merge_request = true AND pre_merge_check = true) AS mr_train,\n    countIf(ref = 'master' and source = 'push') AS master_push,\n    countIf(ref = 'master' and source = 'schedule') AS master_schedule\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND source != 'parent_pipeline'\nGROUP BY time\nORDER BY time",
    unit='short',
    showValues=false,
    description='Amount of executed pipelines',
    legendCalcs=['median', 'mean'],
  ),
  gridPos={ x: 0, y: 10, w: 12, h: 11 },
)
.addPanel(
  panels.timeSeriesPanel(
    'Successful Pipeline Counts',
    "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    countIf(is_merge_request = true AND pre_merge_check = false) AS mr,\n    countIf(is_merge_request = true AND pre_merge_check = true) AS mr_train,\n    countIf(ref = 'master' and source = 'push') AS master_push,\n    countIf(ref = 'master' and source = 'schedule') AS master_schedule\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND source != 'parent_pipeline'\n    AND status = 'success'\nGROUP BY time\nORDER BY time",
    unit='short',
    showValues=false,
    description='Amount of executed pipelines',
    legendCalcs=['median', 'mean'],
  ),
  gridPos={ x: 12, y: 10, w: 12, h: 11 },
)
.addPanel(
  panels.timeSeriesPanel(
    'Failed Pipeline Counts',
    "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    countIf(is_merge_request = true AND pre_merge_check = false) AS mr,\n    countIf(is_merge_request = true AND pre_merge_check = true) AS mr_train,\n    countIf(ref = 'master' and source = 'push') AS master_push,\n    countIf(ref = 'master' and source = 'schedule') AS master_schedule\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND source != 'parent_pipeline'\n    AND status = 'failed'\nGROUP BY time\nORDER BY time",
    unit='short',
    showValues=false,
    description='Amount of executed pipelines',
    legendCalcs=['median', 'mean'],
  ),
  gridPos={ x: 0, y: 21, w: 12, h: 11 },
)
.addPanel(
  panels.timeSeriesPanel(
    'Canceled Pipeline Counts',
    "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    countIf(is_merge_request = true AND pre_merge_check = false) AS mr,\n    countIf(is_merge_request = true AND pre_merge_check = true) AS mr_train,\n    countIf(ref = 'master' and source = 'push') AS master_push,\n    countIf(ref = 'master' and source = 'schedule') AS master_schedule\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND source != 'parent_pipeline'\n    AND status = 'canceled'\nGROUP BY time\nORDER BY time",
    unit='short',
    showValues=false,
    description='Amount of executed pipelines',
    legendCalcs=['median', 'mean'],
  ),
  gridPos={ x: 12, y: 21, w: 12, h: 11 },
)
.addPanel(
  row.new(title='Duration data', collapse=true)
  .addPanel(
    panels.timeSeriesPanel(
      'MR pipeline duration [minutes]',
      "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    avg(duration) / 60 AS average,\n    quantile(0.95)(duration) / 60 AS p95,\n    quantile(0.80)(duration) / 60 AS p80,\n    quantile(0.50)(duration) / 60 AS p50\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND is_merge_request = true\n    AND source != 'parent_pipeline'\n    AND pre_merge_check = false\n    AND status != 'canceled'\nGROUP BY time\nORDER BY time",
      unit='none',
      axisLabel='minutes',
      showValues=false,
      description='Pipeline duration distribution for merge request pipelines'
    ) + {
      options+: {
        legend+: {
          calcs: ['mean', 'last'],
          displayMode: 'table',
          placement: 'right',
        },
      },
    },
    gridPos={ x: 0, y: 0, w: 24, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Push master pipeline duration [minutes]',
      "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    avg(duration) / 60 AS average,\n    quantile(0.95)(duration) / 60 AS p95,\n    quantile(0.80)(duration) / 60 AS p80,\n    quantile(0.50)(duration) / 60 AS p50\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND ref = 'master'\n    AND source = 'push'\n    AND status != 'canceled'\nGROUP BY time\nORDER BY time",
      unit='none',
      axisLabel='minutes',
      showValues=false,
      description='Pipeline duration for master branch pipelines triggered by push events'
    ),
    gridPos={ x: 0, y: 11, w: 12, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Scheduled master pipeline duration [minutes]',
      "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    avg(duration) / 60 AS average,\n    quantile(0.95)(duration) / 60 AS p95,\n    quantile(0.80)(duration) / 60 AS p80,\n    quantile(0.50)(duration) / 60 AS p50\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND ref = 'master'\n    AND source = 'schedule'\n    AND status != 'canceled'\nGROUP BY time\nORDER BY time",
      unit='none',
      axisLabel='minutes',
      showValues=false,
      description='Pipeline duration for scheduled master branch pipelines'
    ),
    gridPos={ x: 12, y: 11, w: 12, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Queue duration [minutes]',
      "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    avg(mean_queued_duration) / 60 AS average,\n    quantile(0.95)(mean_queued_duration) / 60 AS p95,\n    quantile(0.80)(mean_queued_duration) / 60 AS p80,\n    quantile(0.50)(mean_queued_duration) / 60 AS p50\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND status != 'canceled'\nGROUP BY time\nORDER BY time",
      unit='none',
      axisLabel='minutes',
      showValues=false,
      description='Mean queue times of builds within single pipeline'
    ),
    gridPos={ x: 0, y: 22, w: 12, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Slowest build times [minutes]',
      "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    avg(slowest_build) / 60 AS average,\n    quantile(0.95)(slowest_build) / 60 AS p95,\n    quantile(0.80)(slowest_build) / 60 AS p80,\n    quantile(0.50)(slowest_build) / 60 AS p50\nFROM ci_metrics.finished_pipelines_mv\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\n    AND status != 'canceled'\nGROUP BY time\nORDER BY time",
      unit='none',
      axisLabel='minutes',
      showValues=false,
      description='Duration of longest running build in a pipeline'
    ),
    gridPos={ x: 12, y: 22, w: 12, h: 11 },
  ),
  gridPos={ x: 0, y: 32, w: 24, h: 1 },
)
.addPanel(
  row.new(title='Job data', collapse=true)
  .addPanel(
    panels.timeSeriesPanel(
      'MR pipeline job counts',
      "SELECT\n    toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,\n    avg(builds) AS average,\n    quantile(0.95)(builds) AS p95,\n    quantile(0.80)(builds) AS p80,\n    quantile(0.50)(builds) AS p50\nFROM (\n    SELECT\n        id,\n        min(created_at) AS timestamp,\n        sum(total_builds) AS builds\n    FROM ci_metrics.finished_pipelines_mv\n    WHERE\n        $__timeFilter(created_at)\n        AND project_path = '${project_path}'\n        AND is_merge_request = true\n        AND pre_merge_check = false\n    GROUP BY id\n)\nGROUP BY time\nORDER BY time",
      unit='short',
      showValues=false,
      description='Amount of jobs within a pipeline including all child pipelines'
    ),
    gridPos={ x: 0, y: 0, w: 12, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Master pipeline job counts',
      "SELECT\n    toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,\n    avg(total_builds) AS average,\n    quantile(0.95)(total_builds) AS p95,\n    quantile(0.80)(total_builds) AS p80,\n    quantile(0.50)(total_builds) AS p50\nFROM (\n    SELECT\n        id,\n        min(created_at) AS timestamp,\n        sum(total_builds) AS total_builds\n    FROM ci_metrics.finished_pipelines_mv\n    WHERE\n        $__timeFilter(created_at)\n        AND project_path = '${project_path}'\n        AND ref = 'master'\n    GROUP BY id\n)\nGROUP BY time\nORDER BY time",
      unit='short',
      showValues=false,
      description='Amount of jobs within a pipeline including all child pipelines'
    ),
    gridPos={ x: 12, y: 0, w: 12, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'MR pipeline job failure rate',
      "SELECT\n    toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,\n    avg(failed_builds * 100.0 / nullIf(builds, 0)) AS average,\n    quantile(0.95)(failed_builds * 100.0 / nullIf(builds, 0)) AS p95,\n    quantile(0.80)(failed_builds * 100.0 / nullIf(builds, 0)) AS p80,\n    quantile(0.50)(failed_builds * 100.0 / nullIf(builds, 0)) AS p50\nFROM (\n    SELECT\n        id,\n        min(created_at) AS timestamp,\n        sum(total_builds) AS builds,\n        sum(failed_builds) AS failed_builds\n    FROM ci_metrics.finished_pipelines_mv\n    WHERE\n        $__timeFilter(created_at)\n        AND project_path = '${project_path}'\n        AND is_merge_request = true\n        AND pre_merge_check = false\n    GROUP BY id\n)\nGROUP BY time\nORDER BY time",
      unit='percent',
      showValues=false,
      description='Percentage of jobs that failed within a pipeline'
    ),
    gridPos={ x: 0, y: 11, w: 12, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Master pipeline job failure rate',
      "SELECT\n    toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,\n    avg(failed_builds * 100.0 / nullIf(total_builds, 0)) AS average,\n    quantile(0.95)(failed_builds * 100.0 / nullIf(total_builds, 0)) AS p95,\n    quantile(0.80)(failed_builds * 100.0 / nullIf(total_builds, 0)) AS p80,\n    quantile(0.50)(failed_builds * 100.0 / nullIf(total_builds, 0)) AS p50\nFROM (\n    SELECT\n        id,\n        min(created_at) AS timestamp,\n        sum(total_builds) AS total_builds,\n        sum(failed_builds) AS failed_builds\n    FROM ci_metrics.finished_pipelines_mv\n    WHERE\n        $__timeFilter(created_at)\n        AND project_path = '${project_path}'\n        AND ref = 'master'\n    GROUP BY id\n)\nGROUP BY time\nORDER BY time",
      unit='percent',
      showValues=false,
      description='Percentage of jobs that failed within a pipeline'
    ),
    gridPos={ x: 12, y: 11, w: 12, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'MR allowed to fail builds',
      "SELECT\n    toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,\n    avg(allowed_to_fail_builds * 100.0 / nullIf(builds, 0)) AS average,\n    quantile(0.95)(allowed_to_fail_builds * 100.0 / nullIf(builds, 0)) AS p95,\n    quantile(0.80)(allowed_to_fail_builds * 100.0 / nullIf(builds, 0)) AS p80,\n    quantile(0.50)(allowed_to_fail_builds * 100.0 / nullIf(builds, 0)) AS p50\nFROM (\n    SELECT\n        id,\n        min(created_at) AS timestamp,\n        sum(total_builds) AS builds,\n        sum(allowed_to_fail_builds) AS allowed_to_fail_builds\n    FROM ci_metrics.finished_pipelines_mv\n    WHERE\n        $__timeFilter(created_at)\n        AND project_path = '${project_path}'\n        AND is_merge_request = true\n        AND pre_merge_check = false\n    GROUP BY id\n)\nGROUP BY time\nORDER BY time",
      unit='percent',
      showValues=false,
      description='Percentage of jobs within a single pipeline that are allowed to fail'
    ),
    gridPos={ x: 0, y: 22, w: 12, h: 11 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Master allowed to fail builds',
      "SELECT\n    toStartOfInterval(timestamp, INTERVAL 1 ${aggregation}) AS time,\n    avg(allowed_to_fail_builds * 100.0 / nullIf(total_builds, 0)) AS average,\n    quantile(0.95)(allowed_to_fail_builds * 100.0 / nullIf(total_builds, 0)) AS p95,\n    quantile(0.80)(allowed_to_fail_builds * 100.0 / nullIf(total_builds, 0)) AS p80,\n    quantile(0.50)(allowed_to_fail_builds * 100.0 / nullIf(total_builds, 0)) AS p50\nFROM (\n    SELECT\n        id,\n        min(created_at) AS timestamp,\n        sum(total_builds) AS total_builds,\n        sum(allowed_to_fail_builds) AS allowed_to_fail_builds\n    FROM ci_metrics.finished_pipelines_mv\n    WHERE\n        $__timeFilter(created_at)\n        AND project_path = '${project_path}'\n        AND ref = 'master'\n    GROUP BY id\n)\nGROUP BY time\nORDER BY time",
      unit='percent',
      showValues=false,
      description='Percentage of jobs within a single pipeline that are allowed to fail'
    ),
    gridPos={ x: 12, y: 22, w: 12, h: 11 },
  ),
  gridPos={ x: 0, y: 33, w: 24, h: 1 },
)
.addPanel(
  row.new(title='CI Load', collapse=true)
  .addPanel(
    panels.timeSeriesPanel(
      'Running pipelines',
      "SELECT\n  $__timeInterval(created_at) as time,\n  count(*) as running_pipelines\nFROM ci_metrics.pipeline_metrics\nWHERE \n  $__timeFilter(created_at)\n  AND project_path = '${project_path}'\n  AND status = 'running'\nGROUP BY time\nORDER BY time",
      unit='short',
      showValues=false,
      description='Amount of pipelines triggered within a time period'
    ),
    gridPos={ x: 0, y: 0, w: 12, h: 8 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Running jobs',
      "SELECT\n  $__timeInterval(created_at) as time,\n  count(*) as running_jobs\nFROM ci_metrics.build_metrics\nWHERE \n  $__timeFilter(created_at)\n  AND project_path = '${project_path}'\n  AND status = 'running'\nGROUP BY time\nORDER BY time",
      unit='short',
      showValues=false,
      description='Amount of jobs triggered within a time period'
    ),
    gridPos={ x: 12, y: 0, w: 12, h: 8 },
  ),
  gridPos={ x: 0, y: 34, w: 24, h: 1 },
)
.addPanel(
  row.new(title='CI Cost', collapse=true)
  .addPanel(
    {
      type: 'stat',
      title: 'Average CI Cost per ${aggregation}',
      datasource: panels.clickHouseDatasource,
      description: 'Total CI cost in the project based on the compute time used by CI runners.',
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
        reduceOptions: { calcs: ['mean'], fields: '', values: false },
        showPercentChange: true,
        textMode: 'auto',
        wideLayout: true,
      },
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    sum(cost) as non_mr\nFROM ci_metrics.pipeline_costs FINAL\nWHERE\n    $__timeFilter(created_at)\n    AND (\n        (project_path = '${project_path}' AND mr_iid = 0)\n        OR (source_project_path = '${project_path}' AND source_mr_iid = 0)\n    )\nGROUP BY time\nORDER BY time",
          refId: 'A',
        },
        {
          datasource: panels.clickHouseDatasource,
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    sum(cost) as mr\nFROM ci_metrics.pipeline_costs FINAL\nWHERE\n    $__timeFilter(created_at)\n    AND (\n        (project_path = '${project_path}' AND mr_iid != 0)\n        OR (source_project_path = '${project_path}' AND source_mr_iid != 0)\n    )\nGROUP BY time\nORDER BY time",
          refId: 'B',
        },
      ],
      transformations: [
        {
          id: 'calculateField',
          options: {
            alias: 'Total',
            binary: {
              left: { matcher: { id: 'byName', options: 'non_mr A' } },
              right: { matcher: { id: 'byName', options: 'mr B' } },
            },
            mode: 'binary',
            reduce: { reducer: 'sum' },
          },
        },
        {
          id: 'organize',
          options: {
            excludeByName: {},
            includeByName: {},
            indexByName: {},
            renameByName: { 'mr B': 'MR', 'non_mr A': 'Non-MR' },
          },
        },
      ],
    },
    gridPos={ x: 0, y: 0, w: 6, h: 10 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      'Total CI Cost',
      "SELECT\n    toStartOfInterval(created_at, INTERVAL 1 ${aggregation}) AS time,\n    sum(case when mr_iid = 0 then cost else 0 end) as non_mr,\n    sum(case when mr_iid != 0 then cost else 0 end) as mr,\n    sum(cost) as total\nFROM ci_metrics.pipeline_costs FINAL\nWHERE\n    $__timeFilter(created_at)\n    AND project_path = '${project_path}'\nGROUP BY time\nORDER BY time",
      unit='currencyUSD',
      showValues=false,
      description='Total CI cost in the project broken down by MR and non-MR pipelines',
      legendCalcs=['median', 'mean'],
      legendPlacement='right'
    ),
    gridPos={ x: 6, y: 0, w: 18, h: 10 },
  )
  ,
  gridPos={ x: 0, y: 35, w: 24, h: 1 },
)
