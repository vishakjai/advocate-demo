local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;

(basic.dashboard(
   title='Test File Runtime Overview',
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
    "SELECT DISTINCT ci_project_path\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE pipeline_type = 'default_branch_pipeline'\n  AND $__timeFilter(timestamp)\nORDER BY ci_project_path",
    current='gitlab-org/gitlab',
    includeAll=false,
    refresh='load',
  ),
)
.addTemplate(
  template.new(
    'run_type',
    panels.clickHouseDatasource,
    "SELECT DISTINCT run_type\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE ci_project_path = '${project}'\n  AND $__timeFilter(timestamp)\nORDER BY run_type",
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
    "SELECT DISTINCT pipeline_type\nFROM test_metrics.test_results_hourly_projects_run_types_mv\nWHERE ci_project_path = '${project}'\nAND run_type IN (${run_type:singlequote})\nAND $__timeFilter(timestamp)\nAND pipeline_type != 'any'\nAND pipeline_type != 'unknown'\nORDER BY run_type",
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
    "SELECT DISTINCT group\nFROM test_metrics.test_results_hourly_ownership_data_mv\nWHERE ci_project_path = '${project}'\nAND run_type IN (${run_type:singlequote})\nAND pipeline_type IN (${pipeline_type:singlequote})\nAND $__timeFilter(timestamp)\nORDER BY group",
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
        'runtime',
        "SELECT\n  file_path,\n  round(avg(avg_file_runtime) / 60000.0, 2) as file_runtime_min,\n  avg(avg_test_count) as test_count,\n  group,\n  any(feature_category) as feature_category\nFROM test_metrics.test_results_passed_test_file_runtime FINAL\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND group IN (${group:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND $__timeFilter(timestamp)\nGROUP BY file_path, group\nORDER BY file_runtime_min DESC\nLIMIT 50;",
        description='Top 50 slowest spec files',
        overrides=[
          {
            matcher: { id: 'byName', options: 'file_path' },
            properties: [
              { id: 'custom.width', value: 600 },
              {
                id: 'links',
                value: [
                  {
                    targetBlank: true,
                    title: 'spec overview',
                    url: '/d/' + config.uid('single-test-overview.dashboard.jsonnet') + '?from=${__from}&to=${__to}&${project:queryparam}&${run_type:queryparam}&${pipeline_type:queryparam}&var-file_path=${__value.raw}&var-group=${__data.fields.group}',
                  },
                ],
              },
            ],
          },
        ],
      ),
      gridPos={ x: 0, y: 1, w: 24, h: 11 },
    )
    .addPanel(
      panels.piePanel(
        'runtime distribution by group',
        "SELECT\n  group,\n  round(sum(avg_file_runtime) / 1000.0, 2) as total_avg_runtime_seconds\nFROM (\n  SELECT\n    file_path,\n    group,\n    avg(avg_file_runtime) as avg_file_runtime\n  FROM test_metrics.test_results_passed_test_file_runtime FINAL\n  WHERE ci_project_path = '${project}'\n    AND run_type IN (${run_type:singlequote})\n    AND pipeline_type IN (${pipeline_type:singlequote})\n    AND $__timeFilter(timestamp)\n  GROUP BY file_path, group\n)\nGROUP BY group\nORDER BY total_avg_runtime_seconds DESC;",
        description='Distribution of total average file runtimes by group',
      ),
      gridPos={ x: 0, y: 12, w: 12, h: 14 },
    )
    .addPanel(
      panels.piePanel(
        'runtime distribution by test file',
        "SELECT\n  file_path,\n  round(avg(avg_file_runtime) / 1000.0, 2) as avg_file_runtime_seconds\nFROM test_metrics.test_results_passed_test_file_runtime FINAL\nWHERE ci_project_path = '${project}'\n  AND run_type IN (${run_type:singlequote})\n  AND group IN (${group:singlequote})\n  AND pipeline_type IN (${pipeline_type:singlequote})\n  AND $__timeFilter(timestamp)\nGROUP BY file_path\nORDER BY avg_file_runtime_seconds DESC\nLIMIT 50;",
        description='Top 50 slowest test file distribution',
      ),
      gridPos={ x: 12, y: 12, w: 12, h: 14 },
    )
  ) + {
    repeat: 'pipeline_type',
  },
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
