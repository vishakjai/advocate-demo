local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;

(basic.dashboard(
   title='Test File Failure Overview',
   tags=config.testMetricsTags,
   time_from='now-30d',
   time_to='now',
   includeEnvironmentTemplate=false,
   includeStandardEnvironmentAnnotations=false,
   includePrometheusDatasourceTemplate=false,
 ) + { timezone: 'browser' })
.addTemplate(
  template.new(
    'project',
    panels.clickHouseDatasource,
    "SELECT DISTINCT ci_project_path\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE timestamp >= $__fromTime\n  AND timestamp <= $__toTime\n  AND pipeline_type = 'default_branch_pipeline'\nORDER BY ci_project_path",
    current='gitlab-org/gitlab',
    includeAll=false,
    multi=true,
    refresh='load',
  ),
)
.addTemplate(
  template.new(
    'run_type',
    panels.clickHouseDatasource,
    'SELECT DISTINCT run_type\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE ci_project_path IN (${project:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nORDER BY run_type',
    current='All',
    includeAll=true,
    multi=true,
    refresh='load',
  ),
)
.addTemplate(
  template.new(
    'pipeline_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT pipeline_type\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE ci_project_path IN (${project:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\n  AND pipeline_type != 'any'\n  AND pipeline_type != 'unknown'\nORDER BY run_type",
    current='All',
    includeAll=true,
    multi=true,
    refresh='load',
  ),
)
.addTemplate(
  template.new(
    'group',
    panels.clickHouseDatasource,
    'SELECT DISTINCT group\nFROM test_metrics.test_results_hourly_ownership_data_mv\nWHERE ci_project_path IN (${project:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nORDER BY group',
    current='All',
    includeAll=true,
    refresh='load',
  ),
)
.addPanel(
  (
    row.new(title='${pipeline_type}', collapse=true)
    .addPanel(
      panels.tablePanel(
        'failure rate',
        "SELECT\n  ci_project_path,\n  file_path,\n  group,\n  sum(jobs_with_failures) as jobs_with_failure,\n  sum(total_jobs) as jobs_total,\n  round(sum(jobs_with_failures) / nullIf(sum(total_jobs), 0), 2) as failure_rate\nFROM test_metrics.test_results_test_file_failure_counts\nFINAL\nWHERE ci_project_path IN (${project:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND pipeline_type = '${pipeline_type}'\n  AND group IN (${group:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY ci_project_path, file_path, group\nHAVING jobs_with_failure > 0\nORDER BY jobs_with_failure DESC, failure_rate DESC\nLIMIT 100",
        description='Spec files with highest failure rate based on the amount of jobs they failed in',
        overrides=[
          {
            matcher: { id: 'byName', options: 'ci_project_path' },
            properties: [
              { id: 'custom.width', value: 220 },
              { id: 'displayName', value: 'project' },
            ],
          },
          {
            matcher: { id: 'byName', options: 'file_path' },
            properties: [
              { id: 'custom.width', value: 500 },
              {
                id: 'links',
                value: [
                  {
                    targetBlank: true,
                    title: 'Show details',
                    url: '/d/' + config.uid('single-test-overview.dashboard.jsonnet') + '?from=${__from}&to=${__to}&${project:queryparam}&${run_type:queryparam}&${pipeline_type:queryparam}&var-file_path=${__value.raw}&var-group=${__data.fields.group}',
                  },
                ],
              },
            ],
          },
          {
            matcher: { id: 'byName', options: 'failure_rate' },
            properties: [{ id: 'unit', value: 'percentunit' }],
          },
        ],
      ),
      gridPos={ x: 0, y: 1, w: 24, h: 12 },
    )
    .addPanel(
      panels.tablePanel(
        'retry rate',
        "SELECT\n  ci_project_path,\n  file_path,\n  group,\n  sum(jobs_with_retries) as jobs_with_retry,\n  sum(total_jobs) as jobs_total,\n  round(sum(jobs_with_retries) / nullIf(sum(total_jobs), 0), 2) as retry_rate\nFROM test_metrics.test_results_test_file_failure_counts\nFINAL\nWHERE ci_project_path IN (${project:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND pipeline_type = '${pipeline_type}'\n  AND group IN (${group:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY ci_project_path, file_path, group\nHAVING jobs_with_retry > 0\nORDER BY jobs_with_retry DESC, retry_rate DESC\nLIMIT 100",
        description='Spec files with highest retry rate based on the amount of jobs they were retried in',
        overrides=[
          {
            matcher: { id: 'byName', options: 'ci_project_path' },
            properties: [
              { id: 'custom.width', value: 220 },
              { id: 'displayName', value: 'project' },
            ],
          },
          {
            matcher: { id: 'byName', options: 'file_path' },
            properties: [
              { id: 'custom.width', value: 500 },
              {
                id: 'links',
                value: [
                  {
                    targetBlank: true,
                    title: 'Show details',
                    url: '/d/' + config.uid('single-test-overview.dashboard.jsonnet') + '?from=${__from}&to=${__to}&${project:queryparam}&${run_type:queryparam}&${pipeline_type:queryparam}&var-file_path=${__value.raw}&var-group=${__data.fields.group}',
                  },
                ],
              },
            ],
          },
          {
            matcher: { id: 'byName', options: 'retry_rate' },
            properties: [{ id: 'unit', value: 'percentunit' }],
          },
        ],
      ),
      gridPos={ x: 0, y: 13, w: 24, h: 12 },
    )
    .addPanel(
      panels.piePanel(
        'failure distribution by group',
        "SELECT\n  group,\n  sum(jobs_with_failures) as jobs_with_failure\nFROM test_metrics.test_results_test_file_failure_counts\nFINAL\nWHERE ci_project_path IN (${project:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND pipeline_type = '${pipeline_type}'\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY group\nHAVING jobs_with_failure > 0\nORDER BY jobs_with_failure DESC\nLIMIT 20",
        description='Amount of jobs failed by tests from particular feature category',
      ),
      gridPos={ x: 0, y: 13, w: 10, h: 13 },
    )
    .addPanel(
      panels.piePanel(
        'failure distribution by test file',
        "SELECT\n  concat(ci_project_path, ': ', file_path) as file_path,\n  sum(jobs_with_failures) as jobs_with_failure\nFROM test_metrics.test_results_test_file_failure_counts\nFINAL\nWHERE ci_project_path IN (${project:singlequote})\n  AND run_type IN (${run_type:singlequote})\n  AND pipeline_type = '${pipeline_type}'\n  AND group IN (${group:singlequote})\n  AND timestamp >= $__fromTime\n  AND timestamp <= $__toTime\nGROUP BY ci_project_path, file_path\nHAVING jobs_with_failure > 0\nORDER BY jobs_with_failure DESC\nLIMIT 20",
        description='Amount of jobs spec file has failed in',
        overrides=[
          {
            __systemRef: 'hideSeriesFrom',
            matcher: {
              id: 'byNames',
              options: {
                mode: 'exclude',
                names: ['jobs_with_failure'],
                prefix: 'All except:',
                readOnly: true,
              },
            },
            properties: [
              {
                id: 'custom.hideFrom',
                value: { legend: false, tooltip: true, viz: true },
              },
            ],
          },
        ],
      ),
      gridPos={ x: 10, y: 13, w: 14, h: 13 },
    )
  ) + {
    repeat: 'pipeline_type',
  },
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
