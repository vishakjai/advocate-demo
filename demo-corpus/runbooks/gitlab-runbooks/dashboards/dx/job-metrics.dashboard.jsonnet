local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local template = grafana.template;

local minRunsTemplate = template.custom(
  'min_runs',
  '5, 10, 20',
  '10',
) + {
  description: 'Minimum amount of runs to consider for tables displaying least successful and slowest jobs',
};

local projectPathTemplate = template.new(
  'project_path',
  panels.clickHouseDatasource,
  'SELECT DISTINCT project_path\nFROM ci_metrics.pipeline_metrics\nWHERE created_at >= $__fromTime\n  AND created_at <= $__toTime\nORDER BY project_path',
  current='gitlab-org/gitlab',
  includeAll=false,
);

local jobNameTemplate = template.new(
  'job_name',
  panels.clickHouseDatasource,
  "SELECT DISTINCT name\nFROM ci_metrics.distinct_build_names_mv\nWHERE project_path = '${project_path}'\n  AND created_at >= $__fromTime\n  AND created_at <= $__toTime\nORDER BY name",
  refresh='time',
  includeAll=true,
  multi=true,
) + {
  description: 'Job name filter for runtime and success rate charts',
};

(basic.dashboard(
   'Job Metrics',
   tags=config.ciMetricsTags,
   includeEnvironmentTemplate=false,
   includeStandardEnvironmentAnnotations=false,
   includePrometheusDatasourceTemplate=false,
   time_from='now-30d',
   time_to='now',
   uid='ci-job-metrics',
 ) + { timezone: 'browser' })
.addTemplate(minRunsTemplate)
.addTemplate(projectPathTemplate)
.addTemplate(jobNameTemplate)
.addPanel(
  panels.tablePanel(
    title='Least successful jobs',
    rawSql=|||
      SELECT
          replaceRegexpOne(name, ' \d+/\d+$', '') AS job_name,
          round(countIf(status = 'success') / count() * 100, 2) AS success_rate,
          countIf(status = 'success') AS successful_runs,
          countIf(status = 'failed') AS failed_runs,
          count() AS total_runs
      FROM ci_metrics.finished_builds_mv
      WHERE $__timeFilter(created_at)
          AND project_path = '${project_path}'
          AND status IN ('success', 'failed')
      GROUP BY job_name
      HAVING total_runs >= ${min_runs}
      ORDER BY success_rate ASC
      LIMIT 100
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'job_name' },
        properties: [
          { id: 'custom.minWidth', value: 300 },
          {
            id: 'links',
            value: [
              {
                targetBlank: false,
                title: 'Job Details',
                url: '/d/' + config.uid('job-metrics.dashboard.jsonnet') + '?var-job_name=${__value.text}',
              },
            ],
          },
        ],
      },
      {
        matcher: { id: 'byName', options: 'success_rate' },
        properties: [
          { id: 'unit', value: 'percent' },
          { id: 'custom.width', value: 150 },
          { id: 'custom.align', value: 'center' },
        ],
      },
      {
        matcher: { id: 'byRegexp', options: '/.*_runs/' },
        properties: [
          { id: 'custom.width', value: 150 },
          { id: 'custom.align', value: 'center' },
        ],
      },
    ],
  ),
  gridPos={ h: 9, w: 24, x: 0, y: 0 },
)
.addPanel(
  panels.tablePanel(
    title='Slowest jobs',
    rawSql=|||
      SELECT
          replaceRegexpOne(name, ' \d+/\d+$', '') AS job_name,
          round(avg(duration), 2) AS avg_duration,
          round(quantile(0.8)(duration), 2) AS p80_duration,
          round(max(duration), 2) AS max_duration,
          count() AS total_runs
      FROM ci_metrics.finished_builds_mv
      WHERE $__timeFilter(created_at)
          AND project_path = '${project_path}'
          AND status IN ('success', 'failed')
      GROUP BY job_name
      HAVING total_runs >= ${min_runs}
      ORDER BY avg_duration DESC
      LIMIT 100
    |||,
    overrides=[
      {
        matcher: { id: 'byRegexp', options: '/.*_duration/' },
        properties: [
          { id: 'unit', value: 's' },
          { id: 'custom.width', value: 150 },
          { id: 'custom.align', value: 'center' },
        ],
      },
      {
        matcher: { id: 'byName', options: 'job_name' },
        properties: [
          { id: 'custom.minWidth', value: 400 },
          {
            id: 'links',
            value: [
              {
                title: 'Job Details',
                url: '/d/' + config.uid('job-metrics.dashboard.jsonnet') + '?var-job_name=${__value.text}',
              },
            ],
          },
        ],
      },
      {
        matcher: { id: 'byName', options: 'total_runs' },
        properties: [
          { id: 'custom.width', value: 150 },
          { id: 'custom.align', value: 'center' },
        ],
      },
    ],
  ),
  gridPos={ h: 9, w: 24, x: 0, y: 9 },
)
.addPanel(
  panels.tablePanel(
    title='Most failed due to timeout',
    rawSql=|||
      SELECT
          replaceRegexpOne(name, ' \d+/\d+$', '') AS job_name,
          round(countIf(failure_reason = 'job_execution_timeout') / countIf(status = 'failed') * 100, 2) AS timeout_failure_rate,
          countIf(failure_reason = 'job_execution_timeout') AS timeout_failures,
          countIf(status = 'failed') AS total_failures,
          count() AS total_runs
      FROM ci_metrics.finished_builds_mv
      WHERE $__timeFilter(created_at)
          AND project_path = '${project_path}'
          AND status IN ('success', 'failed')
      GROUP BY job_name
      HAVING timeout_failures > 5 AND total_runs >= ${min_runs}
      ORDER BY timeout_failure_rate DESC
      LIMIT 100
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'timeout_failure_rate' },
        properties: [
          { id: 'custom.width', value: 150 },
          { id: 'custom.align', value: 'center' },
          { id: 'unit', value: 'percent' },
        ],
      },
      {
        matcher: { id: 'byRegexp', options: '/(.*_failures)|total_runs/' },
        properties: [
          { id: 'custom.width', value: 150 },
          { id: 'custom.align', value: 'center' },
        ],
      },
      {
        matcher: { id: 'byName', options: 'job_name' },
        properties: [
          {
            id: 'links',
            value: [
              {
                title: 'Job Details',
                url: '/d/' + config.uid('job-metrics.dashboard.jsonnet') + '?var-job_name=${__value.text}',
              },
            ],
          },
        ],
      },
    ],
  ),
  gridPos={ h: 9, w: 24, x: 0, y: 18 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='Timed out jobs',
    rawSql=|||
      SELECT
          toStartOfDay(created_at) AS time,
          count() AS timed_out_jobs
      FROM ci_metrics.finished_builds_mv
      WHERE $__timeFilter(created_at)
          AND project_path = '${project_path}'
          AND status = 'failed'
          AND failure_reason = 'job_execution_timeout'
      GROUP BY time
      ORDER BY time
    |||,
    unit='short',
  ) + { description: 'Amount of jobs that failed due to timeout' },
  gridPos={ h: 11, w: 24, x: 0, y: 27 },
)
.addPanel(
  panels.textPanel(
    title='',
    content='# Individual job data\n\nGraphs that contain runtime and success rates for each individual job',
  ),
  gridPos={ h: 3, w: 24, x: 0, y: 38 },
)
.addPanel(
  grafana.row.new(title='Runtime', collapse=true)
  .addPanel(
    panels.timeSeriesPanel(
      title='${job_name}',
      rawSql=|||
        SELECT
            toStartOfDay(created_at) AS time,
            quantile(0.5)(duration) AS p50,
            quantile(0.8)(duration) AS p80,
            quantile(0.9)(duration) AS p90,
            avg(duration) AS average
        FROM ci_metrics.finished_builds_mv
        WHERE $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND name LIKE '${job_name}%'
            AND status = 'success'
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ) + {
      repeat: 'job_name',
      repeatDirection: 'h',
      maxPerRow: 3,
    },
    gridPos={ h: 10, w: 24, x: 0, y: 42 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 41 },
)
.addPanel(
  grafana.row.new(title='Master Success rate', collapse=true)
  .addPanel(
    panels.timeSeriesPanel(
      title='${job_name}',
      rawSql=|||
        SELECT
            toStartOfDay(created_at) AS time,
            countIf(status = 'success') * 100.0 / nullIf(count(), 0) AS success_rate
        FROM ci_metrics.finished_builds_mv
        WHERE $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND name LIKE '${job_name}%'
            AND status IN ('success', 'failed')
            AND ref = 'master'
        GROUP BY time
        ORDER BY time
      |||,
      unit='percent',
    ) + {
      repeat: 'job_name',
      repeatDirection: 'h',
      maxPerRow: 3,
    },
    gridPos={ h: 10, w: 24, x: 0, y: 1385 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 42 },
)
.addPanel(
  grafana.row.new(title='Branch Success Rate', collapse=true)
  .addPanel(
    panels.timeSeriesPanel(
      title='${job_name}',
      rawSql=|||
        SELECT
            toStartOfDay(created_at) AS time,
            countIf(status = 'success') * 100.0 / nullIf(count(), 0) AS success_rate
        FROM ci_metrics.finished_builds_mv
        WHERE $__timeFilter(created_at)
            AND project_path = '${project_path}'
            AND name LIKE '${job_name}%'
            AND status IN ('success', 'failed')
            AND ref != 'master'
        GROUP BY time
        ORDER BY time
      |||,
      unit='percent',
    ) + {
      repeat: 'job_name',
      repeatDirection: 'h',
      maxPerRow: 3,
    },
    gridPos={ h: 10, w: 24, x: 0, y: 1386 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 43 },
)
