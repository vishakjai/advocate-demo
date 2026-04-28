local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;

basic.dashboard(
  title='Timeout Failure Analysis',
  tags=config.failureAnalysisTags + config.ciMetricsTags,
  time_from='now-7d',
  time_to='now',
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  includePrometheusDatasourceTemplate=false,
)
.addTemplate(
  template.custom(
    'failure_category',
    'job_timeouts,rspec_at_80_min',
    'All',
    includeAll=true,
    multi=true,
    label='Failure Category',
  ),
)
.addTemplate(
  template.new(
    'timeout_signature',
    panels.clickHouseDatasource,
    |||
      SELECT DISTINCT failure_signature
      FROM ci_metrics.failure_analysis_metrics
      WHERE $__timeFilter(created_at)
        AND failure_category IN (${failure_category:singlequote})
        AND failure_signature != ''
        AND project_path = 'gitlab-org/gitlab'
      ORDER BY failure_signature
    |||,
    includeAll=true,
    multi=true,
    label='Timeout Signature',
    refresh='time',
  ),
)
.addPanel(
  panels.statPanel(
    title='Timeout Impact On Masters%',
    description='Percentage of master pipeline failures caused by timeout error',
    rawSql=|||
      WITH master_timeout_failures AS (
        SELECT count() AS timeout_failures
        FROM ci_metrics.failure_analysis_metrics
        WHERE $__timeFilter(created_at)
          AND failure_category IN (${failure_category:singlequote})
          AND project_path = 'gitlab-org/gitlab'
          AND ref = 'master'
          AND failure_signature IN (${timeout_signature:singlequote})
      ),
      master_all_failures AS (
        SELECT count() AS total_failures
        FROM ci_metrics.build_metrics
        WHERE $__timeFilter(created_at)
          AND project_path = 'gitlab-org/gitlab'
          AND ref = 'master'
          AND status = 'failed'
          AND allow_failure = false
      )
      SELECT
        round(timeout_failures * 100.0 / nullIf(total_failures, 0), 1) AS master_timeout_pct
      FROM master_timeout_failures, master_all_failures
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'master_timeout_pct' },
        properties: [
          { id: 'color', value: { mode: 'thresholds' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 0, y: 0, w: 5, h: 8 },
)
.addPanel(
  panels.statPanel(
    title='Jobs Timeout %',
    description='Percentage of all failed jobs that were due to timeouts',
    rawSql=|||
      SELECT
        round(
          (SELECT count() FROM ci_metrics.failure_analysis_metrics
           WHERE $__timeFilter(created_at)
           AND failure_category IN (${failure_category:singlequote})
           AND project_path = 'gitlab-org/gitlab'
           AND failure_signature IN (${timeout_signature:singlequote})
          ) * 100.0 / nullIf(count(), 0),
          1
        ) AS jobs_timeout_pct
      FROM ci_metrics.build_metrics
      WHERE $__timeFilter(created_at)
        AND project_path = 'gitlab-org/gitlab'
        AND status = 'failed'
        AND allow_failure = false
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'jobs_timeout_pct' },
        properties: [
          { id: 'color', value: { mode: 'thresholds' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 5, y: 0, w: 5, h: 8 },
)
.addPanel(
  panels.statPanel(
    title='Pipelines Timeout %',
    description='Percentage of failed pipelines that had timeout failures',
    rawSql=|||
      SELECT
        round(
          uniq(b.pipeline_id) * 100.0 / nullIf(
            (SELECT uniq(pipeline_id)
             FROM ci_metrics.build_metrics
             WHERE $__timeFilter(created_at)
               AND project_path = 'gitlab-org/gitlab'
               AND status = 'failed'
               AND allow_failure = false
            ), 0
          ), 1
        ) AS pipelines_timeout_pct
      FROM ci_metrics.build_metrics b
      JOIN ci_metrics.failure_analysis_metrics f ON b.id = f.job_id
      WHERE $__timeFilter(b.created_at)
        AND b.project_path = 'gitlab-org/gitlab'
        AND b.status = 'failed'
        AND f.failure_category IN (${failure_category:singlequote})
        AND f.failure_signature IN (${timeout_signature:singlequote})
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'pipelines_timeout_pct' },
        properties: [
          { id: 'color', value: { mode: 'thresholds' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 10, y: 0, w: 5, h: 8 },
)
.addPanel(
  panels.statPanel(
    title='Distinct Problems',
    description='Number of distinct timeout problems identified.',
    rawSql=|||
      SELECT
        uniq(failure_signature) AS distinct_problems
      FROM ci_metrics.failure_analysis_metrics
      WHERE $__timeFilter(created_at)
        AND failure_category IN (${failure_category:singlequote})
        AND failure_signature != ''
        AND project_path = 'gitlab-org/gitlab'
        AND failure_signature IN (${timeout_signature:singlequote})
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'distinct_problems' },
        properties: [
          { id: 'color', value: { mode: 'thresholds' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 100 }, { color: 'red', value: 200 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 15, y: 0, w: 9, h: 25 },
)
.addPanel(
  panels.statPanel(
    title='Master Failures',
    description='Number of timeout failures on master branch',
    rawSql=|||
      SELECT count() AS master_failures
      FROM ci_metrics.failure_analysis_metrics
      WHERE $__timeFilter(created_at)
        AND failure_category IN (${failure_category:singlequote})
        AND project_path = 'gitlab-org/gitlab'
        AND ref = 'master'
        AND failure_signature IN (${timeout_signature:singlequote})
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'master_failures' },
        properties: [
          { id: 'color', value: { mode: 'thresholds' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 20 }, { color: 'red', value: 50 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 0, y: 8, w: 5, h: 9 },
)
.addPanel(
  panels.statPanel(
    title='Jobs Failed',
    description='Total number of jobs that failed due to timeout.',
    rawSql=|||
      SELECT count() AS jobs_failed
      FROM ci_metrics.failure_analysis_metrics
      WHERE $__timeFilter(created_at)
        AND failure_category IN (${failure_category:singlequote})
        AND project_path = 'gitlab-org/gitlab'
        AND failure_signature IN (${timeout_signature:singlequote})
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'jobs_failed' },
        properties: [
          { id: 'color', value: { mode: 'thresholds' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 300 }, { color: 'red', value: 500 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 5, y: 8, w: 5, h: 9 },
)
.addPanel(
  panels.statPanel(
    title='Pipelines Impacted',
    description='Number of unique pipelines impacted by timeout failures.',
    rawSql=|||
      SELECT
        uniq(b.pipeline_id) AS impacted_pipelines
      FROM ci_metrics.build_metrics b
      JOIN ci_metrics.failure_analysis_metrics f ON b.id = f.job_id
      WHERE $__timeFilter(b.created_at)
        AND b.project_path = 'gitlab-org/gitlab'
        AND b.status = 'failed'
        AND b.allow_failure = false
        AND f.failure_category IN (${failure_category:singlequote})
        AND f.failure_signature IN (${timeout_signature:singlequote})
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'impacted_pipelines' },
        properties: [
          { id: 'color', value: { mode: 'thresholds' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 250 }, { color: 'red', value: 500 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 10, y: 8, w: 5, h: 9 },
)
.addPanel(
  {
    type: 'stat',
    title: 'ΔMaster Failures',
    description: 'Compares master branch failures period over period.',
    datasource: panels.clickHouseDatasource,
    fieldConfig: {
      defaults: { color: { mode: 'thresholds' }, mappings: [], thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] }, unit: 'short' },
      overrides: [],
    },
    options: {
      colorMode: 'value',
      graphMode: 'none',
      justifyMode: 'center',
      orientation: 'auto',
      percentChangeColorMode: 'inverted',
      reduceOptions: { calcs: ['lastNotNull'], fields: '/^delta_display$/', values: false },
      showPercentChange: false,
      textMode: 'auto',
      wideLayout: true,
    },
    targets: [{
      editorType: 'sql',
      format: 1,
      queryType: 'table',
      rawSql: |||
        WITH current_period AS (
          SELECT count() AS current_count
          FROM ci_metrics.failure_analysis_metrics
          WHERE $__timeFilter(created_at)
            AND failure_category IN (${failure_category:singlequote})
            AND project_path = 'gitlab-org/gitlab'
            AND ref = 'master'
            AND failure_signature IN (${timeout_signature:singlequote})
        ),
        previous_period AS (
          SELECT count() AS previous_count
          FROM ci_metrics.failure_analysis_metrics
          WHERE created_at >= $__fromTime - ($__toTime - $__fromTime)
            AND created_at < $__fromTime
            AND failure_category IN (${failure_category:singlequote})
            AND project_path = 'gitlab-org/gitlab'
            AND ref = 'master'
            AND failure_signature IN (${timeout_signature:singlequote})
        )
        SELECT
          current_count - previous_count AS delta_value,
          CASE
            WHEN current_count - previous_count > 0 THEN concat('↑ ', toString(current_count - previous_count))
            WHEN current_count - previous_count < 0 THEN concat('↓ ', toString(abs(current_count - previous_count)))
            ELSE 'FLAT 0'
          END AS delta_display
        FROM current_period, previous_period
      |||,
      refId: 'A',
    }],
  },
  gridPos={ x: 0, y: 17, w: 5, h: 9 },
)
.addPanel(
  {
    type: 'stat',
    title: 'ΔJobs Failed',
    description: 'Compares jobs failed period over period.',
    datasource: panels.clickHouseDatasource,
    fieldConfig: {
      defaults: { color: { mode: 'thresholds' }, mappings: [], thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] }, unit: 'short' },
      overrides: [],
    },
    options: {
      colorMode: 'value',
      graphMode: 'none',
      justifyMode: 'center',
      orientation: 'auto',
      percentChangeColorMode: 'inverted',
      reduceOptions: { calcs: ['lastNotNull'], fields: '/^delta_display$/', values: false },
      showPercentChange: false,
      textMode: 'auto',
      wideLayout: true,
    },
    targets: [{
      editorType: 'sql',
      format: 1,
      queryType: 'table',
      rawSql: |||
        WITH current_period AS (
          SELECT count() AS current_count
          FROM ci_metrics.failure_analysis_metrics
          WHERE $__timeFilter(created_at)
            AND failure_category IN (${failure_category:singlequote})
            AND project_path = 'gitlab-org/gitlab'
            AND failure_signature IN (${timeout_signature:singlequote})
        ),
        previous_period AS (
          SELECT count() AS previous_count
          FROM ci_metrics.failure_analysis_metrics
          WHERE created_at >= $__fromTime - ($__toTime - $__fromTime)
            AND created_at < $__fromTime
            AND failure_category IN (${failure_category:singlequote})
            AND project_path = 'gitlab-org/gitlab'
            AND failure_signature IN (${timeout_signature:singlequote})
        )
         SELECT
           current_count - previous_count AS delta_value,
           CASE
             WHEN current_count - previous_count > 0 THEN concat('↑ ', toString(current_count - previous_count))
             WHEN current_count - previous_count < 0 THEN concat('↓ ', toString(abs(current_count - previous_count)))
             ELSE 'FLAT 0'
           END AS delta_display
         FROM current_period, previous_period
      |||,
      refId: 'A',
    }],
  },
  gridPos={ x: 5, y: 17, w: 5, h: 9 },
)
.addPanel(
  {
    type: 'stat',
    title: 'ΔPipelines Impacted',
    description: 'Compares pipelines impacted period over period.',
    datasource: panels.clickHouseDatasource,
    fieldConfig: {
      defaults: { color: { mode: 'thresholds' }, mappings: [], thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] }, unit: 'short' },
      overrides: [],
    },
    options: {
      colorMode: 'value',
      graphMode: 'none',
      justifyMode: 'center',
      orientation: 'auto',
      percentChangeColorMode: 'inverted',
      reduceOptions: { calcs: ['lastNotNull'], fields: '/^delta_display$/', values: false },
      showPercentChange: false,
      textMode: 'auto',
      wideLayout: true,
    },
    targets: [{
      editorType: 'sql',
      format: 1,
      queryType: 'table',
      rawSql: |||
        WITH current_period AS (
          SELECT uniq(b.pipeline_id) AS current_count
          FROM ci_metrics.build_metrics b
          JOIN ci_metrics.failure_analysis_metrics f ON b.id = f.job_id
          WHERE $__timeFilter(b.created_at)
            AND b.project_path = 'gitlab-org/gitlab'
            AND b.status = 'failed'
            AND f.failure_category IN (${failure_category:singlequote})
            AND f.failure_signature IN (${timeout_signature:singlequote})
        ),
        previous_period AS (
          SELECT uniq(b.pipeline_id) AS previous_count
          FROM ci_metrics.build_metrics b
          JOIN ci_metrics.failure_analysis_metrics f ON b.id = f.job_id
          WHERE b.created_at >= $__fromTime - ($__toTime - $__fromTime)
            AND b.created_at < $__fromTime
            AND b.project_path = 'gitlab-org/gitlab'
            AND b.status = 'failed'
            AND f.failure_category IN (${failure_category:singlequote})
            AND f.failure_signature IN (${timeout_signature:singlequote})
        )
         SELECT
           current_count - previous_count AS delta_value,
           CASE
             WHEN current_count - previous_count > 0 THEN concat('↑ ', toString(current_count - previous_count))
             WHEN current_count - previous_count < 0 THEN concat('↓ ', toString(abs(current_count - previous_count)))
             ELSE 'FLAT 0'
           END AS delta_display
         FROM current_period, previous_period
      |||,
      refId: 'A',
    }],
  },
  gridPos={ x: 10, y: 17, w: 5, h: 9 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='Pipeline Failure Trend',
    description='Timeout failures over time',
    rawSql=|||
      SELECT
        if($__toTime - $__fromTime <= 86400, toStartOfHour(b.created_at), toStartOfDay(b.created_at)) AS time,
        uniq(b.pipeline_id) AS pipelines_with_failures,
        count() AS total_failed_jobs
      FROM ci_metrics.build_metrics b
      JOIN ci_metrics.failure_analysis_metrics f ON b.id = f.job_id
      WHERE $__timeFilter(b.created_at)
        AND b.project_path = 'gitlab-org/gitlab'
        AND b.status = 'failed'
        AND b.allow_failure = false
        AND f.failure_category IN (${failure_category:singlequote})
        AND f.failure_signature IN (${timeout_signature:singlequote})
      GROUP BY time
      ORDER BY time ASC
    |||,
    legendCalcs=['sum', 'mean'],
  ),
  gridPos={ x: 0, y: 26, w: 24, h: 10 },
)
.addPanel(
  {
    type: 'barchart',
    title: 'Top 10 Timeout Problems [Click Bar for more info]',
    description: 'Top 10 timeout problems ranked by failures',
    datasource: panels.clickHouseDatasource,
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisColorMode: 'text',
          axisLabel: '',
          axisPlacement: 'auto',
          fillOpacity: 80,
          gradientMode: 'hue',
          hideFrom: { legend: false, tooltip: false, viz: false },
          lineWidth: 1,
          scaleDistribution: { type: 'linear' },
          thresholdsStyle: { mode: 'off' },
        },
        links: [
          { targetBlank: true, title: 'Open Sample Job', url: '${__data.fields.example_job}' },
          { targetBlank: false, title: 'Filter by this Timeout Signature', url: '/d/${__dashboard.uid}?${__url_time_range}&var-timeout_signature=${__data.fields.timeout_problem.text}' },
        ],
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
      },
      overrides: [],
    },
    options: {
      barRadius: 0.1,
      barWidth: 0.8,
      fullHighlight: false,
      groupWidth: 0.7,
      legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: false },
      orientation: 'horizontal',
      showValue: 'always',
      stacking: 'none',
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
      xTickLabelRotation: 0,
      xTickLabelSpacing: 0,
    },
    targets: [{
      editorType: 'sql',
      format: 1,
      queryType: 'table',
      rawSql: |||
        SELECT
          failure_signature AS timeout_problem,
          count() AS failures,
          any(concat('https://gitlab.com/', project_path, '/-/jobs/', toString(job_id))) AS example_job,
          any(matched_text) AS preview_context
        FROM ci_metrics.failure_analysis_metrics
        WHERE $__timeFilter(created_at)
          AND failure_category IN (${failure_category:singlequote})
          AND failure_signature != ''
          AND project_path = 'gitlab-org/gitlab'
          AND failure_signature IN (${timeout_signature:singlequote})
        GROUP BY failure_signature
        ORDER BY failures DESC
        LIMIT 10
      |||,
      refId: 'A',
    }],
  },
  gridPos={ x: 0, y: 36, w: 16, h: 12 },
)
.addPanel(
  panels.piePanel(
    title='Master vs Merge Requests',
    description='Shows distribution of timeout failures between master and merge requests.',
    rawSql=|||
      SELECT
        CASE
          WHEN ref = 'master' THEN 'Master'
          ELSE 'Merge Requests'
        END AS branch_type,
        count() AS failures
      FROM ci_metrics.failure_analysis_metrics
      WHERE $__timeFilter(created_at)
        AND failure_category IN (${failure_category:singlequote})
        AND project_path = 'gitlab-org/gitlab'
        AND failure_signature IN (${timeout_signature:singlequote})
      GROUP BY branch_type
      ORDER BY failures DESC
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'Master' },
        properties: [{ id: 'color', value: { fixedColor: 'orange', mode: 'fixed' } }],
      },
      {
        matcher: { id: 'byName', options: 'Merge Requests' },
        properties: [{ id: 'color', value: { fixedColor: 'blue', mode: 'fixed' } }],
      },
    ],
  ) + {
    options: {
      displayLabels: ['name', 'percent'],
      legend: {
        displayMode: 'table',
        placement: 'bottom',
        showLegend: true,
        values: ['value', 'percent'],
      },
      pieType: 'donut',
      reduceOptions: {
        calcs: ['lastNotNull'],
        fields: '',
        values: true,
      },
      sort: 'desc',
      tooltip: {
        hideZeros: false,
        mode: 'single',
        sort: 'none',
      },
    },
  },
  gridPos={ x: 16, y: 36, w: 8, h: 12 },
)
.addPanel(
  panels.tablePanel(
    title='Timeout Impact Details',
    description='Detailed breakdown of timeout problems. CI minutes wasted is estimated at ~50 min per timeout based on average hang duration.',
    rawSql=|||
      SELECT
        f.failure_signature AS timeout_signature,
        replaceRegexpAll(replaceRegexpAll(b.name, '\\s*\\d+/\\d+', ''), 'pg\\d+', 'pg') AS job_name,
        uniq(b.pipeline_id) AS pipelines_impacted,
        count() AS jobs_failed,
        count() * 50 AS ci_minutes_wasted,
        any(concat('https://gitlab.com/', f.project_path, '/-/jobs/', toString(f.job_id))) AS example_job_url
      FROM ci_metrics.failure_analysis_metrics f
      JOIN ci_metrics.build_metrics b ON f.job_id = b.id
      WHERE $__timeFilter(f.created_at)
        AND f.failure_category IN (${failure_category:singlequote})
        AND f.failure_signature != ''
        AND f.project_path = 'gitlab-org/gitlab'
        AND f.failure_signature IN (${timeout_signature:singlequote})
      GROUP BY 1, 2
      ORDER BY pipelines_impacted DESC
      LIMIT 20
    |||,
    sortBy=[{ desc: true, displayName: 'pipelines_impacted' }],
    overrides=[
      {
        matcher: { id: 'byName', options: 'ci_minutes_wasted' },
        properties: [{ id: 'unit', value: 'm' }],
      },
      {
        matcher: { id: 'byName', options: 'pipelines_impacted' },
        properties: [
          { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 10 }, { color: 'red', value: 25 }] } },
        ],
      },
      {
        matcher: { id: 'byName', options: 'job_name' },
        properties: [
          { id: 'links', value: [{ targetBlank: true, title: 'Open Example Job', url: '${__data.fields.example_job_url}' }] },
        ],
      },
      {
        matcher: { id: 'byName', options: 'example_job_url' },
        properties: [{ id: 'custom.hideFrom.viz', value: true }],
      },
    ],
  ),
  gridPos={ x: 0, y: 48, w: 24, h: 10 },
)
.addPanel(
  panels.tablePanel(
    title='Timeout Signatures by Affected Jobs',
    description='Each timeout signature and jobs affected',
    rawSql=|||
      WITH signature_stats AS (
        SELECT
          f.failure_signature AS timeout_signature,
          topK(1)(b.name)[1] AS most_common_job_raw,
          replaceRegexpAll(replaceRegexpAll(topK(1)(b.name)[1], '\\s*\\d+/\\d+', ''), 'pg\\d+', 'pg') AS most_common_job,
          arrayStringConcat(groupUniqArray(b.name), ', ') AS all_job_names,
          count() AS total_failures
        FROM ci_metrics.failure_analysis_metrics f
        JOIN ci_metrics.build_metrics b ON f.job_id = b.id
        WHERE $__timeFilter(f.created_at)
          AND f.failure_category IN (${failure_category:singlequote})
          AND f.failure_signature != ''
          AND f.project_path = 'gitlab-org/gitlab'
          AND f.failure_signature IN (${timeout_signature:singlequote})
        GROUP BY f.failure_signature
      ),
      job_counts AS (
        SELECT
          f.failure_signature,
          b.name AS job_name,
          count() AS job_count
        FROM ci_metrics.failure_analysis_metrics f
        JOIN ci_metrics.build_metrics b ON f.job_id = b.id
        WHERE $__timeFilter(f.created_at)
          AND f.failure_category IN (${failure_category:singlequote})
          AND f.failure_signature != ''
          AND f.project_path = 'gitlab-org/gitlab'
          AND f.failure_signature IN (${timeout_signature:singlequote})
        GROUP BY f.failure_signature, b.name
      )
      SELECT
        s.timeout_signature,
        s.most_common_job,
        jc.job_count AS most_common_job_count,
        s.all_job_names,
        s.total_failures
      FROM signature_stats s
      LEFT JOIN job_counts jc
        ON s.timeout_signature = jc.failure_signature
        AND s.most_common_job_raw = jc.job_name
      ORDER BY s.total_failures DESC
      LIMIT 30
    |||,
    sortBy=[{ desc: true, displayName: 'total_failures' }],
  ),
  gridPos={ x: 0, y: 58, w: 24, h: 12 },
)
.addPanel(
  {
    type: 'barchart',
    title: 'Top Failing Jobs by Name',
    description: 'Distribution across job types',
    datasource: panels.clickHouseDatasource,
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisColorMode: 'text',
          axisLabel: '',
          axisPlacement: 'auto',
          fillOpacity: 80,
          gradientMode: 'hue',
          hideFrom: { legend: false, tooltip: false, viz: false },
          lineWidth: 1,
          scaleDistribution: { type: 'linear' },
          thresholdsStyle: { mode: 'off' },
        },
        links: [
          { targetBlank: true, title: 'Open Example Job', url: '${__data.fields.example_job}' },
          { targetBlank: true, title: 'Open Example Pipeline', url: '${__data.fields.example_pipeline}' },
        ],
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
      },
      overrides: [],
    },
    options: {
      barRadius: 0.1,
      barWidth: 0.8,
      fullHighlight: true,
      groupWidth: 0.7,
      legend: { calcs: ['sum'], displayMode: 'table', placement: 'bottom', showLegend: true },
      orientation: 'horizontal',
      showValue: 'always',
      stacking: 'none',
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
      xField: 'job_name',
      xTickLabelRotation: 0,
      xTickLabelSpacing: 0,
    },
    targets: [{
      editorType: 'sql',
      format: 1,
      queryType: 'table',
      rawSql: |||
        SELECT
          replaceRegexpAll(replaceRegexpAll(b.name, '\\s*\\d+/\\d+', ''), 'pg\\d+', 'pg') AS job_name,
          count() AS failures,
          uniq(b.pipeline_id) AS pipelines_impacted,
          any(concat('https://gitlab.com/', b.project_path, '/-/jobs/', toString(b.id))) AS example_job,
          any(concat('https://gitlab.com/', b.project_path, '/-/pipelines/', toString(b.pipeline_id))) AS example_pipeline
        FROM ci_metrics.build_metrics b
        WHERE b.id IN (
          SELECT job_id
          FROM ci_metrics.failure_analysis_metrics
          WHERE $__timeFilter(created_at)
            AND failure_category IN (${failure_category:singlequote})
            AND project_path = 'gitlab-org/gitlab'
            AND failure_signature IN (${timeout_signature:singlequote})
        )
        AND $__timeFilter(b.created_at)
        AND b.project_path = 'gitlab-org/gitlab'
        GROUP BY job_name
        ORDER BY failures DESC
        LIMIT 15
      |||,
      refId: 'A',
    }],
  },
  gridPos={ x: 0, y: 70, w: 16, h: 18 },
)
.addPanel(
  panels.piePanel(
    title='Timeout Retry Outcomes',
    description='Fixed by retry vs still failed',
    rawSql=|||
      WITH ordered_jobs AS (
        SELECT
          bm.pipeline_id,
          bm.name AS job_name,
          bm.status,
          bm.created_at,
          fa.failure_category,
          fa.failure_signature
        FROM ci_metrics.build_metrics bm
        LEFT JOIN ci_metrics.failure_analysis_metrics fa ON bm.id = fa.job_id
        WHERE bm.project_path = 'gitlab-org/gitlab'
          AND $__timeFilter(bm.created_at)
          AND bm.status IN ('success', 'failed')
          AND bm.finished = true
          AND (
            bm.status = 'success'
            OR bm.id IN (
              SELECT job_id FROM ci_metrics.failure_analysis_metrics
              WHERE failure_signature IN (${timeout_signature:singlequote})
            )
          )
        ORDER BY bm.pipeline_id, bm.name, bm.created_at ASC
      ),
      timeout_retries AS (
        SELECT
          pipeline_id,
          job_name,
          groupArray(status) AS statuses,
          groupArray(failure_category) AS categories,
          groupArray(failure_signature) AS signatures
        FROM ordered_jobs
        GROUP BY pipeline_id, job_name
        HAVING length(statuses) > 1
          AND has(categories, 'job_timeouts')
      )
      SELECT
        CASE
          WHEN has(statuses, 'success') THEN 'Fixed by Retry'
          ELSE 'Still Failed After Retry'
        END AS retry_outcome,
        count(*) AS count
      FROM timeout_retries
      GROUP BY retry_outcome
      ORDER BY count DESC
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'Fixed by Retry' },
        properties: [{ id: 'color', value: { fixedColor: 'green', mode: 'fixed' } }],
      },
      {
        matcher: { id: 'byName', options: 'Still Failed After Retry' },
        properties: [{ id: 'color', value: { fixedColor: 'red', mode: 'fixed' } }],
      },
    ],
  ) + {
    options: {
      displayLabels: ['Name', 'Percent'],
      legend: {
        displayMode: 'table',
        placement: 'bottom',
        showLegend: true,
        values: ['value', 'percent'],
      },
      pieType: 'pie',
      reduceOptions: {
        calcs: ['lastNotNull'],
        fields: '',
        values: true,
      },
      sort: 'desc',
      tooltip: {
        hideZeros: false,
        mode: 'single',
        sort: 'none',
      },
    },
  },
  gridPos={ x: 16, y: 70, w: 8, h: 18 },
)
.addPanel(
  panels.tablePanel(
    title='Timeout Signatures with Job Links',
    description='All failed jobs by signature',
    rawSql=|||
      SELECT
        f.failure_signature AS timeout_signature,
        arrayStringConcat(
          arrayMap(
            job_id -> concat('<a href="https://gitlab.com/gitlab-org/gitlab/-/jobs/', toString(job_id), '" target="_blank">#', toString(job_id), '</a>'),
            groupArray(f.job_id)
          ),
          ', '
        ) AS job_urls,
        count() AS total_jobs
      FROM ci_metrics.failure_analysis_metrics f
      WHERE $__timeFilter(f.created_at)
        AND f.failure_category IN (${failure_category:singlequote})
        AND f.failure_signature != ''
        AND f.project_path = 'gitlab-org/gitlab'
        AND f.failure_signature IN (${timeout_signature:singlequote})
      GROUP BY f.failure_signature
      ORDER BY total_jobs DESC
      LIMIT 20
    |||,
    sortBy=[{ desc: true, displayName: 'total_jobs' }],
    overrides=[
      {
        matcher: { id: 'byName', options: 'job_urls' },
        properties: [{ id: 'custom.cellOptions', value: { type: 'markdown' } }],
      },
      {
        matcher: { id: 'byName', options: 'total_jobs' },
        properties: [
          { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: '#EAB839', value: 15 }, { color: 'red', value: 30 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 0, y: 88, w: 24, h: 25 },
)
.addPanel(
  row.new(title='Timeout Retry Analysis: In Depth', collapse=false),
  gridPos={ x: 0, y: 113, w: 24, h: 1 },
)
.addPanel(
  panels.tablePanel(
    title='Timeout Signatures: Retry Success Rate',
    description='Flaky vs persistent issues',
    rawSql=|||
      WITH ordered_jobs AS (
        SELECT
          bm.pipeline_id,
          bm.name,
          bm.status,
          fa.failure_signature,
          fa.failure_category
        FROM ci_metrics.build_metrics bm
        LEFT JOIN ci_metrics.failure_analysis_metrics fa ON bm.id = fa.job_id
        WHERE bm.project_path = 'gitlab-org/gitlab'
          AND $__timeFilter(bm.created_at)
          AND bm.status IN ('success', 'failed')
      ),
      timeout_retries AS (
        SELECT
          pipeline_id,
          name,
          groupArray(status) AS statuses,
          groupArray(failure_category) AS categories,
          anyIf(failure_signature, failure_signature != '') AS timeout_signature
        FROM ordered_jobs
        GROUP BY pipeline_id, name
        HAVING length(statuses) > 1
          AND has(categories, 'job_timeouts')
      )
      SELECT
        timeout_signature,
        countIf(has(statuses, 'success')) AS fixed_by_retry,
        countIf(NOT has(statuses, 'success')) AS still_failed,
        count() AS total_occurrences,
        round(countIf(has(statuses, 'success')) * 100.0 / count(), 1) AS retry_success_rate
      FROM timeout_retries
      WHERE timeout_signature != ''
        AND timeout_signature IN (${timeout_signature:singlequote})
      GROUP BY timeout_signature
      ORDER BY total_occurrences DESC
      LIMIT 20
    |||,
    sortBy=[{ desc: true, displayName: 'total_occurrences' }],
    overrides=[
      {
        matcher: { id: 'byName', options: 'retry_success_rate' },
        properties: [
          { id: 'unit', value: 'percent' },
          { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'gauge', valueDisplayMode: 'text' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 40 }, { color: 'green', value: 70 }] } },
        ],
      },
      {
        matcher: { id: 'byName', options: 'fixed_by_retry' },
        properties: [{ id: 'custom.cellOptions', value: { type: 'color-text' } }, { id: 'color', value: { fixedColor: 'green', mode: 'fixed' } }],
      },
      {
        matcher: { id: 'byName', options: 'still_failed' },
        properties: [{ id: 'custom.cellOptions', value: { type: 'color-text' } }, { id: 'color', value: { fixedColor: 'red', mode: 'fixed' } }],
      },
    ],
  ),
  gridPos={ x: 0, y: 114, w: 21, h: 9 },
)
.addPanel(
  panels.statPanel(
    title='Retry Success Rate',
    description='Percentage succeeded on retry',
    rawSql=|||
      WITH ordered_jobs AS (
        SELECT
          bm.pipeline_id,
          bm.name AS job_name,
          bm.status,
          bm.created_at,
          fa.failure_category,
          fa.failure_signature
        FROM ci_metrics.build_metrics bm
        LEFT JOIN ci_metrics.failure_analysis_metrics fa ON bm.id = fa.job_id
        WHERE bm.project_path = 'gitlab-org/gitlab'
          AND $__timeFilter(bm.created_at)
          AND bm.status IN ('success', 'failed')
          AND bm.finished = true
          AND (
            bm.status = 'success'
            OR bm.id IN (
              SELECT job_id FROM ci_metrics.failure_analysis_metrics
              WHERE failure_signature IN (${timeout_signature:singlequote})
            )
          )
        ORDER BY bm.pipeline_id, bm.name, bm.created_at ASC
      ),
      timeout_retries AS (
        SELECT
          pipeline_id,
          job_name,
          groupArray(status) AS statuses,
          groupArray(failure_category) AS categories,
          groupArray(failure_signature) AS signatures
        FROM ordered_jobs
        GROUP BY pipeline_id, job_name
        HAVING length(statuses) > 1
          AND has(categories, 'job_timeouts')
      )
      SELECT
        round(countIf(has(statuses, 'success')) * 100.0 / count(), 1) AS retry_success_rate
      FROM timeout_retries
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: 'retry_success_rate' },
        properties: [
          { id: 'unit', value: 'percent' },
          { id: 'color', value: { mode: 'thresholds' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 50 }, { color: 'green', value: 70 }] } },
        ],
      },
    ],
  ),
  gridPos={ x: 21, y: 114, w: 3, h: 9 },
)
.addPanel(
  row.new(title='Timeout pattern by Day and Hour', collapse=false),
  gridPos={ x: 0, y: 123, w: 24, h: 1 },
)
.addPanel(
  panels.tablePanel(
    title='Timeout Heatmap: Day & Hour',
    description='When failures occur most',
    rawSql=|||
      SELECT
        CASE toDayOfWeek(created_at)
          WHEN 1 THEN '1-Mon'
          WHEN 2 THEN '2-Tue'
          WHEN 3 THEN '3-Wed'
          WHEN 4 THEN '4-Thu'
          WHEN 5 THEN '5-Fri'
          WHEN 6 THEN '6-Sat'
          WHEN 7 THEN '7-Sun'
        END AS day,
        countIf(toHour(created_at) >= 0 AND toHour(created_at) < 6) AS "00-06h",
        countIf(toHour(created_at) >= 6 AND toHour(created_at) < 12) AS "06-12h",
        countIf(toHour(created_at) >= 12 AND toHour(created_at) < 18) AS "12-18h",
        countIf(toHour(created_at) >= 18 AND toHour(created_at) < 24) AS "18-24h",
        count() AS total
      FROM ci_metrics.failure_analysis_metrics
      WHERE $__timeFilter(created_at)
        AND failure_category IN (${failure_category:singlequote})
        AND project_path = 'gitlab-org/gitlab'
        AND failure_signature IN (${timeout_signature:singlequote})
      GROUP BY toDayOfWeek(created_at), day
      ORDER BY toDayOfWeek(created_at)
    |||,
    overrides=[
      {
        matcher: { id: 'byName', options: '00-06h' },
        properties: [
          { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 10 }, { color: 'orange', value: 25 }, { color: 'red', value: 50 }] } },
        ],
      },
      {
        matcher: { id: 'byName', options: '06-12h' },
        properties: [
          { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 10 }, { color: 'orange', value: 25 }, { color: 'red', value: 50 }] } },
        ],
      },
      {
        matcher: { id: 'byName', options: '12-18h' },
        properties: [
          { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 10 }, { color: 'orange', value: 25 }, { color: 'red', value: 50 }] } },
        ],
      },
      {
        matcher: { id: 'byName', options: '18-24h' },
        properties: [
          { id: 'custom.cellOptions', value: { mode: 'gradient', type: 'color-background' } },
          { id: 'thresholds', value: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 10 }, { color: 'orange', value: 25 }, { color: 'red', value: 50 }] } },
        ],
      },
      {
        matcher: { id: 'byName', options: 'total' },
        properties: [
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
          { id: 'color', value: { fixedColor: 'blue', mode: 'fixed' } },
        ],
      },
      {
        matcher: { id: 'byName', options: 'day' },
        properties: [{ id: 'custom.width', value: 80 }],
      },
    ],
  ),
  gridPos={ x: 0, y: 124, w: 24, h: 10 },
)
