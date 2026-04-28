local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;

local overviewStatsQuery =
  "SELECT\n  COUNT(DISTINCT btf.ci_pipeline_id) as blocked_pipelines,\n  COUNT(DISTINCT btf.ci_job_id) as failed_jobs,\n  min(btf.timestamp) as first_seen,\n  max(btf.timestamp) as last_seen\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.run_type IN (${run_type:singlequote})\n  AND btf.pipeline_type IN (${pipeline_type:singlequote})\n  AND btf.file_path = '${file_path}'\n  AND btf.location IN (${test_location:singlequote})\n  AND btf.exception_classes[1] IN (${exception_class:singlequote})\n  AND $__timeFilter(btf.timestamp)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'";

basic.dashboard(
  title='Flaky Test File Failure Overview',
  uid='Test-file-failure-overview',
  tags=['flaky-tests'] + config.testMetricsTags,
  time_from='now-30d',
  time_to='now',
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  includePrometheusDatasourceTemplate=false,
)
.addTemplate(
  template.new(
    'project',
    panels.clickHouseDatasource,
    "SELECT DISTINCT ci_project_path\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY ci_project_path",
    current='gitlab-org/gitlab',
  ),
)
.addTemplate(
  template.new(
    'run_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT run_type \nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY run_type",
    includeAll=true,
  ),
)
.addTemplate(
  template.new(
    'pipeline_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT pipeline_type \nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY pipeline_type",
    includeAll=true,
  ),
)
.addTemplate(
  template.new(
    'file_path',
    panels.clickHouseDatasource,
    "SELECT DISTINCT file_path\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY file_path;",
  ),
)
.addTemplate(
  template.new(
    'test_location',
    panels.clickHouseDatasource,
    "SELECT DISTINCT location\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.file_path = '${file_path}'\n  AND btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY location",
    includeAll=true,
    multi=true,
  ),
)
.addTemplate(
  template.new(
    'exception_class',
    panels.clickHouseDatasource,
    "SELECT DISTINCT exception_classes[1] AS exception_class\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.file_path = '${file_path}'\n  AND btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nORDER BY exception_class",
    includeAll=true,
    multi=true,
  ),
)

.addPanel(
  row.new(title='Overview', collapse=false),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanel(
  panels.statPanel('Blocked CI Pipelines', 'blocked_pipelines', overviewStatsQuery),
  gridPos={ x: 2, y: 1, w: 5, h: 7 },
)
.addPanel(
  panels.statPanel('First Seen', 'first_seen', overviewStatsQuery),
  gridPos={ x: 7, y: 1, w: 5, h: 7 },
)
.addPanel(
  panels.statPanel('Last Seen', 'last_seen', overviewStatsQuery),
  gridPos={ x: 12, y: 1, w: 5, h: 7 },
)
.addPanel(
  panels.statPanel(
    'Co-failing Test Files',
    'avg_co_failing_files',
    "SELECT\n  round(avg(total_files - 1), 1) as avg_co_failing_files\nFROM (\n  SELECT\n    btf.ci_job_id,\n    COUNT(DISTINCT other.file_path) as total_files\n  FROM test_metrics.blocking_test_failures_mv btf\n  INNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\n  INNER JOIN test_metrics.blocking_test_failures_mv other ON btf.ci_job_id = other.ci_job_id\n  WHERE btf.ci_project_path = '${project}'\n    AND btf.run_type IN (${run_type:singlequote})\n    AND btf.pipeline_type IN (${pipeline_type:singlequote})\n    AND btf.file_path = '${file_path}'\n    AND btf.timestamp >= toDateTime($__from / 1000)\n    AND btf.timestamp <= toDateTime($__to / 1000)\n    AND bm.allow_failure = false\n    AND bm.status = 'failed'\n    AND other.ci_project_path = '${project}'\n    AND other.timestamp >= toDateTime($__from / 1000)\n    AND other.timestamp <= toDateTime($__to / 1000)\n  GROUP BY btf.ci_job_id\n)"
  ),
  gridPos={ x: 17, y: 1, w: 5, h: 7 },
)

.addPanel(
  row.new(title='Trends', collapse=false),
  gridPos={ x: 0, y: 8, w: 24, h: 1 },
)
.addPanel(
  panels.timeSeriesPanel(
    'Pipeline Failures Trend',
    "SELECT \n  toStartOfInterval(btf.timestamp, INTERVAL greatest($__interval_s * 2, 3600) second) as timestamp,\n  btf.location as test_location,\n  COUNT(DISTINCT btf.ci_pipeline_id) as blocked_pipelines\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.run_type IN (${run_type:singlequote})\n  AND btf.pipeline_type IN (${pipeline_type:singlequote})\n  AND btf.file_path = '${file_path}'\n  AND btf.location IN (${test_location:singlequote})\n  AND btf.exception_classes[1] IN (${exception_class:singlequote})\n  AND $__timeFilter(btf.timestamp)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nGROUP BY timestamp, btf.location\nORDER BY timestamp",
    displayName='${__field.labels.test_location}',
    axisLabel='blocked pipelines',
  ),
  gridPos={ x: 0, y: 9, w: 24, h: 10 },
)

.addPanel(
  row.new(title='Failure Analysis', collapse=false),
  gridPos={ x: 0, y: 19, w: 24, h: 1 },
)
.addPanel(
  panels.piePanel(
    'Exception Distribution',
    "SELECT\n  exception_classes[1] AS exception_class,\n  count(*) as count\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.run_type IN (${run_type:singlequote})\n  AND btf.pipeline_type IN (${pipeline_type:singlequote})\n  AND btf.file_path = '${file_path}'\n  AND btf.location IN (${test_location:singlequote})\n  AND btf.exception_classes[1] IN (${exception_class:singlequote})\n  AND btf.timestamp >= toDateTime($__from / 1000)\n  AND btf.timestamp <= toDateTime($__to / 1000)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nGROUP BY exception_class\nORDER BY count DESC;"
  ),
  gridPos={ x: 0, y: 20, w: 8, h: 10 },
)
.addPanel(
  panels.piePanel(
    'Pipeline Type Distribution',
    "SELECT\n  btf.pipeline_type,\n  COUNT(DISTINCT btf.ci_pipeline_id) as blocked_pipelines\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.run_type IN (${run_type:singlequote})\n  AND btf.pipeline_type IN (${pipeline_type:singlequote})\n  AND btf.file_path = '${file_path}'\n  AND btf.location IN (${test_location:singlequote})\n  AND btf.exception_classes[1] IN (${exception_class:singlequote})\n  AND $__timeFilter(btf.timestamp)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nGROUP BY btf.pipeline_type\nORDER BY blocked_pipelines DESC"
  ),
  gridPos={ x: 8, y: 20, w: 8, h: 10 },
)
.addPanel(
  panels.piePanel(
    'Run Type Distribution',
    "SELECT\n  btf.run_type,\n  COUNT(DISTINCT btf.ci_pipeline_id) as blocked_pipelines\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.run_type IN (${run_type:singlequote})\n  AND btf.pipeline_type IN (${pipeline_type:singlequote})\n  AND btf.file_path = '${file_path}'\n  AND btf.location IN (${test_location:singlequote})\n  AND btf.exception_classes[1] IN (${exception_class:singlequote})\n  AND $__timeFilter(btf.timestamp)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nGROUP BY btf.run_type\nORDER BY blocked_pipelines DESC"
  ),
  gridPos={ x: 16, y: 20, w: 8, h: 10 },
)

.addPanel(
  row.new(title='Failure Details', collapse=false),
  gridPos={ x: 0, y: 30, w: 24, h: 1 },
)
.addPanel(
  panels.tablePanel(
    'Blocked CI jobs',
    "SELECT\n  max(btf.timestamp) as timestamp,\n  btf.location as test_location,\n  any(concat(btf.ci_server_url, '/', btf.ci_project_path, '/-/blob/master/', \n    if(btf.file_path LIKE 'qa/specs/%', concat('qa/', btf.file_path), btf.file_path),\n    '#L', replaceRegexpOne(btf.location, '.*:(\\\\d+)$', '\\\\1'))) as test_location_url,\n  any(btf.run_type) as run_type,\n  any(btf.pipeline_type) as pipeline_type,\n  btf.ci_pipeline_id as pipeline_id,\n  any(concat(btf.ci_server_url, '/', btf.ci_project_path, '/-/pipelines/', toString(btf.ci_pipeline_id))) as pipeline_url,\n  btf.ci_job_id as job_id,\n  any(concat(btf.ci_server_url, '/', btf.ci_project_path, '/-/jobs/', toString(btf.ci_job_id))) as job_url\nFROM test_metrics.blocking_test_failures_mv btf\nINNER JOIN ci_metrics.build_metrics bm ON btf.ci_job_id = bm.id\nWHERE btf.ci_project_path = '${project}'\n  AND btf.run_type IN (${run_type:singlequote})\n  AND btf.pipeline_type IN (${pipeline_type:singlequote})\n  AND btf.file_path = '${file_path}'\n  AND btf.location IN (${test_location:singlequote})\n  AND btf.exception_classes[1] IN (${exception_class:singlequote})\n  AND $__timeFilter(btf.timestamp)\n  AND bm.allow_failure = false\n  AND bm.status = 'failed'\nGROUP BY job_id, pipeline_id, test_location\nORDER BY timestamp DESC",
    overrides=[
      {
        matcher: { id: 'byName', options: 'test_location' },
        properties: [
          { id: 'links', value: [{ targetBlank: true, title: '${__value.text}', url: '${__data.fields[test_location_url]}' }] },
          { id: 'custom.width', value: 400 },
        ],
      },
      {
        matcher: { id: 'byName', options: 'pipeline_id' },
        properties: [
          { id: 'links', value: [{ targetBlank: true, title: '${__value.text}', url: '${__data.fields[pipeline_url]}' }] },
          { id: 'custom.width', value: 150 },
        ],
      },
      {
        matcher: { id: 'byName', options: 'job_id' },
        properties: [
          { id: 'links', value: [{ targetBlank: true, title: '${__value.text}', url: '${__data.fields[job_url]}' }] },
          { id: 'custom.width', value: 150 },
        ],
      },
      {
        matcher: { id: 'byName', options: 'test_location_url' },
        properties: [{ id: 'custom.hideFrom.viz', value: true }],
      },
      {
        matcher: { id: 'byName', options: 'pipeline_url' },
        properties: [{ id: 'custom.hideFrom.viz', value: true }],
      },
      {
        matcher: { id: 'byName', options: 'job_url' },
        properties: [{ id: 'custom.hideFrom.viz', value: true }],
      },
    ]
  ),
  gridPos={ x: 0, y: 31, w: 24, h: 10 },
) + { timezone: 'browser' }
