// Shared configuration for Developer Experience dashboards
// Only contains items used by 2+ dashboards

local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;

{
  // ============================================================================
  // CONFIGURATION
  // ============================================================================

  datasource:: 'Development Analytics ClickHouse',
  datasourceUid:: 'P3AA52CBE89C5194B',

  // ============================================================================
  // DASHBOARD TAGS
  // ============================================================================

  testMetricsTags:: ['test-metrics'],
  ciMetricsTags:: ['ci-metrics'],
  codeCoverageTags:: ['code-coverage'],
  failureAnalysisTags:: ['failure-analysis'],

  // ============================================================================
  // TEMPLATE VARIABLES
  // ============================================================================

  sectionTemplate:: template.new(
    'section',
    $.datasource,
    |||
      SELECT DISTINCT section
      FROM "code_coverage"."category_owners"
      UNION ALL SELECT 'Uncategorized'
      ORDER BY 1 ASC
    |||,
    refresh='load',
    includeAll=true,
    allValues="'All'",
  ),

  stageTemplate:: template.new(
    'stage',
    $.datasource,
    |||
      SELECT DISTINCT stage
      FROM "code_coverage"."category_owners"
      UNION ALL SELECT 'Uncategorized'
      ORDER BY 1 ASC
    |||,
    refresh='load',
    includeAll=true,
    allValues="'All'",
  ),

  groupTemplate:: template.new(
    'group',
    $.datasource,
    |||
      SELECT DISTINCT "group"
      FROM "code_coverage"."category_owners"
      UNION ALL SELECT 'Uncategorized'
      ORDER BY 1 ASC
    |||,
    refresh='load',
    includeAll=true,
    allValues="'All'",
  ),

  categoryTemplate:: template.new(
    'category',
    $.datasource,
    |||
      SELECT DISTINCT category
      FROM "code_coverage"."category_owners"
      UNION ALL SELECT 'Uncategorized'
      ORDER BY 1 ASC
    |||,
    refresh='load',
    includeAll=true,
    allValues="'All'",
  ),

  sourceFileTypeTemplate:: template.new(
    'source_file_type',
    $.datasource,
    |||
      SELECT DISTINCT source_file_type
      FROM "code_coverage"."coverage_metrics"
      ORDER BY source_file_type ASC
    |||,
    refresh='load',
    includeAll=true,
    allValues="'All'",
  ),

  // Adds all standard templates to a dashboard
  addStandardTemplates(dashboard)::
    dashboard
    .addTemplate($.sectionTemplate)
    .addTemplate($.stageTemplate)
    .addTemplate($.groupTemplate)
    .addTemplate($.categoryTemplate)
    .addTemplate($.sourceFileTypeTemplate),

  // ============================================================================
  // DASHBOARD NAVIGATION
  // ============================================================================

  uid(filename):: 'dx-' + std.split(filename, '.')[0],

  backToHealthCheckLink:: grafana.link.dashboards(
    'Back to Health Check',
    '',
    asDropdown=false,
    includeVars=true,
    keepTime=true,
    icon='arrow-left',
    url='/d/dx-code-coverage-health-check/dx-code-coverage-health-check',
    targetBlank=false,
    type='link',
  ),
}
