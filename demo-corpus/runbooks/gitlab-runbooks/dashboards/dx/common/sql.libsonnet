// Shared SQL helpers for Developer Experience dashboards
// Only contains items used by 2+ dashboards

{
  // ============================================================================
  // TABLE CONSTANTS
  // ============================================================================

  coverageMetricsTable:: '"code_coverage"."coverage_metrics"',
  testFileMappingsTable:: '"shared"."test_file_mappings"',

  gitlabProjectPath:: 'gitlab-org/gitlab',
  gitlabFossProjectPath:: 'gitlab-org/gitlab-foss',

  // ============================================================================
  // NORMALIZATION FUNCTIONS
  // ============================================================================

  // Removes './' prefix from source file paths
  normalizeSourceFilePath(field):: 'replaceOne(' + field + ", './', '')",

  // Removes './' prefix and line number suffixes (e.g., ':123, ')
  normalizeTestFilePath(field):: 'replaceRegexpOne(replaceOne(' + field + ", './', ''), ':\\\\d+, ', '')",

  // ============================================================================
  // FILTER FRAGMENTS
  // ============================================================================

  ciProjectPath:: 'gitlab-org/gitlab',
  ciProjectPathFilter:: "ci_project_path = '" + $.ciProjectPath + "'",

  // Generic time range filter - works for date, timestamp, and hour_timestamp columns
  // Usage: WHERE %s % [sql.timeRangeFilter('date')]
  timeRangeFilter(field):: field + ' >= $__fromTime AND ' + field + ' <= $__toTime',

  // Filters by section/stage/group/category/source_file_type template variables with 'Uncategorized' support
  // Requires: LEFT JOIN "code_coverage"."category_owners" co ON cm.category = co.category
  categoryOwnerFilterConditionsWithUncategorized:: |||
    CASE WHEN ${section:singlequote} = 'All' THEN true WHEN ${section:singlequote} = 'Uncategorized' THEN co.section IS NULL ELSE co.section = ${section:singlequote} END
      AND CASE WHEN ${stage:singlequote} = 'All' THEN true WHEN ${stage:singlequote} = 'Uncategorized' THEN co.stage IS NULL ELSE co.stage = ${stage:singlequote} END
      AND CASE WHEN ${group:singlequote} = 'All' THEN true WHEN ${group:singlequote} = 'Uncategorized' THEN co.group IS NULL ELSE co.group = ${group:singlequote} END
      AND CASE WHEN ${category:singlequote} = 'All' THEN true WHEN ${category:singlequote} = 'Uncategorized' THEN cm.category IS NULL ELSE cm.category = ${category:singlequote} END
      AND (${source_file_type:singlequote} = 'All' OR cm.source_file_type = ${source_file_type:singlequote})
  |||,

  // ============================================================================
  // SUBQUERIES
  // ============================================================================

  // Returns most recent timestamp per source_file_type (simple version for queries without filters)
  // Usage: WHERE (source_file_type, timestamp) IN (%s) % [sql.latestCoverageMetricsSubquery]
  latestCoverageMetricsSubquery:: |||
    SELECT source_file_type, MAX(timestamp)
    FROM "code_coverage"."coverage_metrics"
    WHERE ci_project_path = 'gitlab-org/gitlab'
    GROUP BY source_file_type
  |||,

  // Returns most recent timestamp per source_file_type with filters applied and Uncategorized support
  latestCoverageMetricsSubqueryWithUncategorized:: |||
    (cm.source_file_type, cm.timestamp) IN (
        SELECT cm2.source_file_type, MAX(cm2.timestamp)
        FROM "code_coverage"."coverage_metrics" cm2
        LEFT JOIN "code_coverage"."category_owners" co2 ON cm2.category = co2.category
        WHERE CASE WHEN ${section:singlequote} = 'All' THEN true WHEN ${section:singlequote} = 'Uncategorized' THEN co2.section IS NULL ELSE co2.section = ${section:singlequote} END
          AND CASE WHEN ${stage:singlequote} = 'All' THEN true WHEN ${stage:singlequote} = 'Uncategorized' THEN co2.stage IS NULL ELSE co2.stage = ${stage:singlequote} END
          AND CASE WHEN ${group:singlequote} = 'All' THEN true WHEN ${group:singlequote} = 'Uncategorized' THEN co2.group IS NULL ELSE co2.group = ${group:singlequote} END
          AND CASE WHEN ${category:singlequote} = 'All' THEN true WHEN ${category:singlequote} = 'Uncategorized' THEN cm2.category IS NULL ELSE cm2.category = ${category:singlequote} END
          AND (${source_file_type:singlequote} = 'All' OR cm2.source_file_type = ${source_file_type:singlequote})
        GROUP BY cm2.source_file_type
    )
  |||,

  // ============================================================================
  // CASE EXPRESSIONS
  // ============================================================================

  // Converts risk score (1-4) to Risk Level string (CRITICAL/HIGH/MEDIUM/LOW)
  riskLevelCase(scoreField='risk_score'):: |||
    CASE %s
      WHEN 4 THEN 'CRITICAL'
      WHEN 3 THEN 'HIGH'
      WHEN 2 THEN 'MEDIUM'
      WHEN 1 THEN 'LOW'
      ELSE '-'
    END
  ||| % scoreField,
}
