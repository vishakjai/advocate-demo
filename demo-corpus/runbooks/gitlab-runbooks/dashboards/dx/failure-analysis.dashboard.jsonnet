local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local row = grafana.row;
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';

basic.dashboard(
  title='Failure Analysis Dashboard',
  tags=config.failureAnalysisTags + config.ciMetricsTags,
  time_from='now-30d',
  time_to='now',
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  includePrometheusDatasourceTemplate=false,
)
.addTemplate(
  template.new(
    'project_path_var',
    panels.clickHouseDatasource,
    'SELECT DISTINCT project_path FROM ci_metrics.failure_analysis_metrics GROUP BY project_path',
    current='gitlab-org/gitlab,gitlab-org/gitlab-foss',
    includeAll=true,
    multi=true,
    refresh='time',
    label='Project',
  ) + { allValue: '', description: 'Select project(s) to analyze.' },
)
.addTemplate(
  template.new(
    'failure_category_var',
    panels.clickHouseDatasource,
    |||
      SELECT DISTINCT failure_category
      FROM ci_metrics.failure_analysis_metrics
      WHERE failure_category != ''
        AND created_at >= now() - INTERVAL 90 DAY
      ORDER BY failure_category
    |||,
    includeAll=true,
    multi=true,
    refresh='time',
    label='Failure Category',
  ) + { allValue: '', description: 'Filter by specific failure category.' },
)
.addTemplate(
  template.new(
    'failure_signature_var',
    panels.clickHouseDatasource,
    |||
      SELECT failure_signature
      FROM ci_metrics.failure_analysis_metrics
      WHERE failure_signature != ''
        AND created_at >= now() - INTERVAL 90 DAY
        AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
        AND (length('${failure_category_var:pipe}') = 0 OR match(failure_category, '^(${failure_category_var:pipe})$'))
      GROUP BY failure_signature
      ORDER BY count() DESC
      LIMIT 500
    |||,
    includeAll=true,
    multi=true,
    refresh='time',
    label='Failure Signature',
  ) + { allValue: '', description: 'Filter by specific failure signature.' },
)
.addPanel(
  row.new(title='Overview', collapse=false),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanel(
  {
    type: 'stat',
    title: 'Failing pipelines with selected filters',
    datasource: panels.clickHouseDatasource,
    description: 'Blocking pipelines with at least one job matching the selected failure categories and signatures, out of all blocking pipelines in the selected time range.',
    fieldConfig: {
      defaults: {
        color: { fixedColor: '#5794f2', mode: 'fixed' },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
        unit: 'string',
      },
      overrides: [],
    },
    options: {
      colorMode: 'value',
      graphMode: 'none',
      justifyMode: 'center',
      orientation: 'auto',
      percentChangeColorMode: 'standard',
      reduceOptions: { calcs: ['lastNotNull'], fields: '/^summary$/', values: false },
      showPercentChange: false,
      text: { valueSize: 38 },
      textMode: 'value',
      wideLayout: true,
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: |||
          SELECT concat(
            toString(uniq(b.pipeline_id)),
            ' (',
            toString(round(
              uniq(b.pipeline_id)
              * 100.0 / nullIf((
                SELECT uniq(pipeline_id)
                FROM ci_metrics.build_metrics
                WHERE $__timeFilter(created_at)
                  AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
                  AND status = 'failed'
                  AND allow_failure = false
              ), 0), 1
            )),
            '%)'
          ) AS summary
          FROM ci_metrics.build_metrics b
          JOIN ci_metrics.failure_analysis_metrics f ON b.id = f.job_id
          WHERE $__timeFilter(b.created_at)
            AND (length('${project_path_var:pipe}') = 0 OR match(b.project_path, '^(${project_path_var:pipe})$'))
            AND b.status = 'failed'
            AND b.allow_failure = false
            AND (length('${failure_category_var:pipe}') = 0 OR match(f.failure_category, '^(${failure_category_var:pipe})$'))
            AND (length('${failure_signature_var:pipe}') = 0 OR match(f.failure_signature, '^(${failure_signature_var:pipe})$'))
        |||,
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 7, y: 1, w: 10, h: 4 },
)
.addPanel(
  row.new(title='Spike Detection', collapse=false),
  gridPos={ x: 0, y: 5, w: 24, h: 1 },
)
.addPanel(
  {
    type: 'timeseries',
    title: 'Pipeline failure impact',
    datasource: panels.clickHouseDatasource,
    description: |||
      Unique blocking pipelines with failures vs total failed jobs over time. A spike in pipelines indicates widespread impact; a spike in jobs only may indicate a single bad MR.
    |||,
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisColorMode: 'text',
          axisPlacement: 'auto',
          barAlignment: 0,
          barWidthFactor: 0.6,
          drawStyle: 'line',
          fillOpacity: 0,
          gradientMode: 'none',
          hideFrom: { legend: false, tooltip: false, viz: false },
          insertNulls: false,
          lineInterpolation: 'linear',
          lineWidth: 2,
          pointSize: 5,
          scaleDistribution: { type: 'linear' },
          showPoints: 'auto',
          showValues: false,
          spanNulls: false,
          stacking: { group: 'A', mode: 'none' },
          thresholdsStyle: { mode: 'off' },
        },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [{ color: 'green', value: 0 }],
        },
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'pipelines_with_failures' },
          properties: [
            { id: 'displayName', value: 'Failed pipelines' },
            { id: 'color', value: { fixedColor: 'red', mode: 'fixed' } },
          ],
        },
        {
          matcher: { id: 'byName', options: 'total_failed_jobs' },
          properties: [
            { id: 'displayName', value: 'Failed jobs' },
            { id: 'color', value: { fixedColor: 'orange', mode: 'fixed' } },
          ],
        },
      ],
    },
    options: {
      legend: {
        calcs: ['max', 'sum'],
        displayMode: 'table',
        placement: 'bottom',
        showLegend: true,
      },
      tooltip: { hideZeros: false, mode: 'multi', sort: 'desc' },
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 0,
        queryType: 'timeseries',
        rawSql: |||
          SELECT
            if($__toTime - $__fromTime <= 86400, toStartOfHour(b.created_at), toStartOfDay(b.created_at)) AS time,
            uniq(b.pipeline_id) AS pipelines_with_failures,
            count() AS total_failed_jobs
          FROM ci_metrics.build_metrics b
          JOIN ci_metrics.failure_analysis_metrics f ON b.id = f.job_id
          WHERE $__timeFilter(b.created_at)
            AND (length('${project_path_var:pipe}') = 0 OR match(b.project_path, '^(${project_path_var:pipe})$'))
            AND b.status = 'failed'
            AND b.allow_failure = false
            AND (length('${failure_category_var:pipe}') = 0 OR match(f.failure_category, '^(${failure_category_var:pipe})$'))
          GROUP BY time
          ORDER BY time ASC
        |||,
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 6, w: 24, h: 13 },
)
.addPanel(
  {
    type: 'table',
    title: 'Recent job failures',
    datasource: panels.clickHouseDatasource,
    description: 'Most recent 500 blocking job failures matching the selected filters.',
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        custom: {
          align: 'left',
          cellOptions: { type: 'auto' },
          filterable: true,
          footer: { reducers: [] },
          inspect: false,
          wrapHeaderText: true,
          wrapText: false,
        },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'created at' },
          properties: [{ id: 'custom.width', value: 160 }],
        },
        {
          matcher: { id: 'byName', options: 'project' },
          properties: [{ id: 'custom.width', value: 180 }],
        },
        {
          matcher: { id: 'byName', options: 'job name' },
          properties: [{ id: 'custom.width', value: 360 }],
        },
        {
          matcher: { id: 'byName', options: 'failure category' },
          properties: [
            { id: 'custom.width', value: 152 },
            {
              id: 'links',
              value: [{
                title: '',
                url: '/d/dx-failure-analysis?${__url_time_range}&${project_path_var:queryparam}&var-failure_category_var=${__value.raw}&var-failure_signature_var=',
                targetBlank: false,
              }],
            },
          ],
        },
        {
          matcher: { id: 'byName', options: 'failure signature' },
          properties: [
            { id: 'custom.width', value: 260 },
            {
              id: 'links',
              value: [{
                title: '',
                url: '/d/dx-failure-analysis?${__url_time_range}&${project_path_var:queryparam}&var-failure_category_var=${__data.fields["failure category"]}&var-failure_signature_var=${__value.raw}',
                targetBlank: false,
              }],
            },
          ],
        },
        {
          matcher: { id: 'byName', options: 'pipeline' },
          properties: [
            { id: 'custom.width', value: 100 },
            {
              id: 'links',
              value: [{
                title: 'Open pipeline',
                url: '${__data.fields.pipeline_url}',
                targetBlank: true,
              }],
            },
          ],
        },
        {
          matcher: { id: 'byName', options: 'job' },
          properties: [
            { id: 'custom.width', value: 110 },
            {
              id: 'links',
              value: [{
                title: 'Open job',
                url: '${__data.fields.job_url}',
                targetBlank: true,
              }],
            },
          ],
        },
        {
          matcher: { id: 'byName', options: 'pipeline_url' },
          properties: [{ id: 'custom.hidden', value: true }],
        },
        {
          matcher: { id: 'byName', options: 'job_url' },
          properties: [{ id: 'custom.hidden', value: true }],
        },
      ],
    },
    options: {
      cellHeight: 'sm',
      enablePagination: false,
      showHeader: true,
      sortBy: [{ desc: true, displayName: 'created at' }],
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: |||
          SELECT
            f.created_at AS "created at",
            f.project_path AS project,
            f.job_name AS "job name",
            f.failure_category AS "failure category",
            f.failure_signature AS "failure signature",
            b.pipeline_id AS pipeline,
            concat('https://gitlab.com/', f.project_path, '/-/pipelines/', toString(b.pipeline_id)) AS pipeline_url,
            f.job_id AS job,
            concat('https://gitlab.com/', f.project_path, '/-/jobs/', toString(f.job_id)) AS job_url
          FROM ci_metrics.failure_analysis_metrics f
          JOIN ci_metrics.build_metrics b ON f.job_id = b.id
          WHERE $__timeFilter(f.created_at)
            AND b.status = 'failed'
            AND b.allow_failure = false
            AND (length('${project_path_var:pipe}') = 0 OR match(f.project_path, '^(${project_path_var:pipe})$'))
            AND (length('${failure_category_var:pipe}') = 0 OR match(f.failure_category, '^(${failure_category_var:pipe})$'))
            AND (length('${failure_signature_var:pipe}') = 0 OR match(f.failure_signature, '^(${failure_signature_var:pipe})$'))
          ORDER BY f.created_at DESC
          LIMIT 500
        |||,
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 19, w: 24, h: 10 },
)
.addPanel(
  {
    type: 'barchart',
    title: 'Failing pipelines by failure category',
    datasource: panels.clickHouseDatasource,
    description: 'Failure categories ranked by number of failing blocking pipelines in the selected time range.',
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisColorMode: 'text',
          axisPlacement: 'auto',
          fillOpacity: 80,
          gradientMode: 'none',
          hideFrom: { legend: false, tooltip: false, viz: false },
          lineWidth: 1,
          scaleDistribution: { type: 'linear' },
          thresholdsStyle: { mode: 'off' },
        },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
      },
      overrides: [],
    },
    options: {
      barRadius: 0,
      barWidth: 1,
      fullHighlight: false,
      groupWidth: 0.7,
      legend: { calcs: ['max', 'sum'], displayMode: 'table', placement: 'bottom', showLegend: true, sortBy: 'Total', sortDesc: true },
      orientation: 'auto',
      showValue: 'auto',
      stacking: 'normal',
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
      xTickLabelRotation: 0,
      xTickLabelSpacing: 0,
    },
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 0,
        queryType: 'timeseries',
        rawSql: |||
          WITH top_categories AS (
              SELECT f.failure_category
              FROM ci_metrics.failure_analysis_metrics f
              JOIN ci_metrics.build_metrics b ON f.job_id = b.id
              PREWHERE $__timeFilter(f.created_at)
              WHERE (length('${project_path_var:pipe}') = 0 OR match(f.project_path, '^(${project_path_var:pipe})$'))
                  AND (length('${failure_category_var:pipe}') = 0 OR match(f.failure_category, '^(${failure_category_var:pipe})$'))
                  AND b.status = 'failed'
                  AND b.allow_failure = false
              GROUP BY f.failure_category
              ORDER BY uniq(b.pipeline_id) DESC
              LIMIT 20
          )
          SELECT
              if($__toTime - $__fromTime <= 86400, toStartOfHour(f.created_at), toStartOfDay(f.created_at)) AS time,
              f.failure_category,
              uniq(b.pipeline_id) AS pipelines
          FROM ci_metrics.failure_analysis_metrics f
          JOIN ci_metrics.build_metrics b ON f.job_id = b.id
          PREWHERE $__timeFilter(f.created_at)
          WHERE (length('${project_path_var:pipe}') = 0 OR match(f.project_path, '^(${project_path_var:pipe})$'))
              AND (length('${failure_category_var:pipe}') = 0 OR match(f.failure_category, '^(${failure_category_var:pipe})$'))
              AND f.failure_category IN (SELECT failure_category FROM top_categories)
              AND b.status = 'failed'
              AND b.allow_failure = false
          GROUP BY time, f.failure_category
          ORDER BY time ASC
        |||,
        refId: 'A',
      },
    ],
    transformations: [
      {
        id: 'renameByRegex',
        options: { regex: 'pipelines (.*)', renamePattern: '$1' },
      },
    ],
  },
  gridPos={ x: 0, y: 29, w: 24, h: 12 },
)
.addPanel(
  {
    type: 'table',
    title: 'Failure signatures',
    datasource: panels.clickHouseDatasource,
    description: |||
      A failure signature is a normalized pattern extracted from a job's failure output — it identifies the root cause independently of job-specific details like branch names, commit SHAs, or timestamps.
      Jobs sharing the same signature are failing for the same underlying reason.
      Top 50 signatures ranked by number of failing blocking pipelines.
    |||,
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        custom: {
          align: 'left',
          cellOptions: { type: 'auto' },
          filterable: true,
          footer: { reducers: [] },
          inspect: false,
        },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
      },
      overrides: [
        {
          matcher: { id: 'byName', options: 'failure signature' },
          properties: [
            { id: 'custom.width', value: 300 },
            {
              id: 'links',
              value: [{
                title: '',
                url: '/d/dx-failure-analysis?${__url_time_range}&${project_path_var:queryparam}&var-failure_category_var=${__data.fields["failure category"]}&var-failure_signature_var=${__value.raw}',
                targetBlank: false,
              }],
            },
          ],
        },
        {
          matcher: { id: 'byName', options: 'normalized context' },
          properties: [{ id: 'custom.width', value: 500 }],
        },
        {
          matcher: { id: 'byName', options: 'failure category' },
          properties: [
            { id: 'custom.width', value: 260 },
            {
              id: 'links',
              value: [{
                title: '',
                url: '/d/dx-failure-analysis?${__url_time_range}&${project_path_var:queryparam}&var-failure_category_var=${__value.raw}&var-failure_signature_var=',
                targetBlank: false,
              }],
            },
          ],
        },
        { matcher: { id: 'byName', options: 'failing pipelines' }, properties: [{ id: 'custom.width', value: 150 }] },
        { matcher: { id: 'byName', options: 'master' }, properties: [{ id: 'custom.width', value: 130 }] },
        { matcher: { id: 'byName', options: 'non-master' }, properties: [{ id: 'custom.width', value: 150 }] },
        {
          matcher: { id: 'byName', options: 'sample job' },
          properties: [
            { id: 'custom.width', value: 120 },
            {
              id: 'links',
              value: [{
                title: 'Open job',
                url: '${__data.fields.sample_job_url}',
                targetBlank: true,
              }],
            },
          ],
        },
        { matcher: { id: 'byName', options: 'sample_job_url' }, properties: [{ id: 'custom.hidden', value: true }] },
      ],
    },
    options: { cellHeight: 'sm', showHeader: true, sortBy: [{ desc: true, displayName: 'failing pipelines' }] },
    pluginVersion: '12.3.1',
    targets: [
      {
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: |||
          SELECT
            f.failure_signature AS "failure signature",
            any(f.normalized_context) AS "normalized context",
            f.failure_category AS "failure category",
            uniq(b.pipeline_id) AS "failing pipelines",
            uniqIf(b.pipeline_id, f.ref = 'master') AS master,
            uniqIf(b.pipeline_id, f.ref != 'master') AS "non-master",
            any(f.job_id) AS "sample job",
            any(concat('https://gitlab.com/', f.project_path, '/-/jobs/', toString(f.job_id))) AS sample_job_url
          FROM ci_metrics.failure_analysis_metrics f
          JOIN ci_metrics.build_metrics b ON f.job_id = b.id
          WHERE $__timeFilter(f.created_at)
            AND (length('${project_path_var:pipe}') = 0 OR match(f.project_path, '^(${project_path_var:pipe})$'))
            AND (length('${failure_category_var:pipe}') = 0 OR match(f.failure_category, '^(${failure_category_var:pipe})$'))
            AND (length('${failure_signature_var:pipe}') = 0 OR match(f.failure_signature, '^(${failure_signature_var:pipe})$'))
          GROUP BY f.failure_category, f.failure_signature
          ORDER BY "failing pipelines" DESC
          LIMIT 50
        |||,
        refId: 'A',
      },
    ],
  },
  gridPos={ x: 0, y: 41, w: 24, h: 12 },
)
.addPanel(
  row.new(title='Health Metrics', collapse=true)
  .addPanels([
    {
      type: 'stat',
      title: 'Failure categories',
      datasource: panels.clickHouseDatasource,
      description: 'Number of distinct failure categories seen in the selected time range and projects.',
      fieldConfig: {
        defaults: {
          color: { mode: 'fixed', fixedColor: '#5794f2' },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'blue', value: 0 }] },
          unit: 'short',
        },
        overrides: [],
      },
      options: {
        colorMode: 'value',
        graphMode: 'none',
        justifyMode: 'center',
        orientation: 'auto',
        reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
        showPercentChange: false,
        textMode: 'auto',
        wideLayout: true,
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
              uniqIf(failure_category, failure_category != '' AND failure_category != 'no_failure_category_found') AS failure_categories
            FROM ci_metrics.failure_analysis_metrics
            WHERE $__timeFilter(created_at)
              AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
          |||,
          refId: 'A',
        },
      ],
      gridPos: { x: 0, y: 54, w: 6, h: 6 },
    },
    {
      type: 'stat',
      title: '% without failure category',
      datasource: panels.clickHouseDatasource,
      description: 'Percentage of failed jobs that have no failure category assigned. Lower is better.',
      fieldConfig: {
        defaults: {
          color: { mode: 'thresholds' },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 5 }, { color: 'red', value: 15 }] },
          unit: 'percent',
        },
        overrides: [],
      },
      options: {
        colorMode: 'value',
        graphMode: 'none',
        justifyMode: 'center',
        orientation: 'auto',
        reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
        showPercentChange: false,
        textMode: 'auto',
        wideLayout: true,
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
              round(countIf(failure_category = '' OR failure_category = 'no_failure_category_found') * 100.0 / count(), 1) AS pct_without_category
            FROM ci_metrics.failure_analysis_metrics
            WHERE $__timeFilter(created_at)
              AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
          |||,
          refId: 'A',
        },
      ],
      gridPos: { x: 6, y: 54, w: 6, h: 6 },
    },
    {
      type: 'stat',
      title: '% without failure signature',
      datasource: panels.clickHouseDatasource,
      description: 'Percentage of failed jobs that have no failure signature assigned. Lower is better.',
      fieldConfig: {
        defaults: {
          color: { mode: 'thresholds' },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 20 }, { color: 'red', value: 50 }] },
          unit: 'percent',
        },
        overrides: [],
      },
      options: {
        colorMode: 'value',
        graphMode: 'none',
        justifyMode: 'center',
        orientation: 'auto',
        reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
        showPercentChange: false,
        textMode: 'auto',
        wideLayout: true,
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
              round(countIf(failure_signature = '') * 100.0 / count(), 1) AS pct_without_signature
            FROM ci_metrics.failure_analysis_metrics
            WHERE $__timeFilter(created_at)
              AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
          |||,
          refId: 'A',
        },
      ],
      gridPos: { x: 12, y: 54, w: 6, h: 6 },
    },
    {
      type: 'stat',
      title: '% without trace',
      datasource: panels.clickHouseDatasource,
      description: 'Percentage of failed jobs where no trace (matched text or normalized context) was extracted. Lower is better — indicates data pipeline health.',
      fieldConfig: {
        defaults: {
          color: { mode: 'thresholds' },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'yellow', value: 10 }, { color: 'red', value: 25 }] },
          unit: 'percent',
        },
        overrides: [],
      },
      options: {
        colorMode: 'value',
        graphMode: 'none',
        justifyMode: 'center',
        orientation: 'auto',
        reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
        showPercentChange: false,
        textMode: 'auto',
        wideLayout: true,
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
              round(countIf(matched_text = '' AND normalized_context = '') * 100.0 / count(), 1) AS pct_without_trace
            FROM ci_metrics.failure_analysis_metrics
            WHERE $__timeFilter(created_at)
              AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
          |||,
          refId: 'A',
        },
      ],
      gridPos: { x: 18, y: 54, w: 6, h: 6 },
    },
    {
      type: 'timeseries',
      title: 'Jobs without a failure category — trend',
      datasource: panels.clickHouseDatasource,
      description: |||
        Jobs without a recognized failure category over time. Spikes may indicate new failure patterns not yet covered by signature matching, or issues with trace extraction.
        Brush-select a range on this chart to drill into the jobs table below.
      |||,
      fieldConfig: {
        defaults: {
          color: { mode: 'palette-classic' },
          custom: {
            axisBorderShow: false,
            axisColorMode: 'text',
            axisPlacement: 'auto',
            drawStyle: 'line',
            fillOpacity: 0,
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineWidth: 1,
            pointSize: 5,
            scaleDistribution: { type: 'linear' },
            showPoints: 'auto',
            spanNulls: false,
            stacking: { mode: 'none' },
            thresholdsStyle: { mode: 'off' },
          },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
        },
        overrides: [],
      },
      options: {
        legend: { calcs: ['p90', 'max'], displayMode: 'table', placement: 'bottom', showLegend: true },
        tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 0,
          queryType: 'timeseries',
          rawSql: |||
            SELECT
              if($__toTime - $__fromTime <= 86400, toStartOfHour(created_at), toStartOfDay(created_at)) AS time,
              countIf(failure_category = '' OR failure_category = 'no_failure_category_found') AS uncategorized_failures
            FROM ci_metrics.failure_analysis_metrics
            WHERE $__timeFilter(created_at)
              AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
            GROUP BY time
            ORDER BY time ASC
          |||,
          refId: 'A',
        },
      ],
      gridPos: { x: 0, y: 60, w: 24, h: 12 },
    },
    {
      type: 'barchart',
      title: 'Top 20 jobs without a failure category',
      datasource: panels.clickHouseDatasource,
      description: 'Job names with the most failures that have no failure category assigned. Use this to prioritize which jobs to investigate and add failure categories for.',
      fieldConfig: {
        defaults: {
          color: { mode: 'thresholds' },
          custom: {
            axisBorderShow: false,
            axisColorMode: 'text',
            axisPlacement: 'auto',
            fillOpacity: 80,
            gradientMode: 'none',
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineWidth: 1,
            scaleDistribution: { type: 'linear' },
            thresholdsStyle: { mode: 'off' },
          },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'blue', value: 0 }] },
        },
        overrides: [],
      },
      options: {
        barRadius: 0,
        barWidth: 0.97,
        colorByField: 'failures',
        fullHighlight: false,
        groupWidth: 0.7,
        legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: false },
        orientation: 'horizontal',
        showValue: 'auto',
        stacking: 'none',
        tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
        xTickLabelRotation: 0,
        xTickLabelSpacing: 0,
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
              job_name,
              count() AS failures
            FROM ci_metrics.failure_analysis_metrics
            WHERE $__timeFilter(created_at)
              AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
              AND (failure_category = '' OR failure_category = 'no_failure_category_found')
            GROUP BY job_name
            ORDER BY failures DESC
            LIMIT 20
          |||,
          refId: 'A',
        },
      ],
      gridPos: { x: 0, y: 72, w: 24, h: 14 },
    },
    {
      type: 'table',
      title: 'Recent jobs without a failure category',
      datasource: panels.clickHouseDatasource,
      description: 'Most recent 200 jobs without a recognized failure category. Brush-select a range on the trend chart above to narrow by time.',
      fieldConfig: {
        defaults: {
          color: { mode: 'thresholds' },
          custom: {
            align: 'left',
            cellOptions: { type: 'auto' },
            filterable: true,
            footer: { reducers: [] },
            inspect: false,
          },
          mappings: [],
          noValue: '—',
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
        },
        overrides: [
          { matcher: { id: 'byName', options: 'created_at' }, properties: [{ id: 'custom.width', value: 160 }, { id: 'displayName', value: 'created at' }] },
          { matcher: { id: 'byName', options: 'project_path' }, properties: [{ id: 'custom.width', value: 180 }, { id: 'displayName', value: 'project' }] },
          { matcher: { id: 'byName', options: 'job_name' }, properties: [{ id: 'custom.width', value: 360 }, { id: 'displayName', value: 'job name' }] },
          { matcher: { id: 'byName', options: 'pipeline_id' }, properties: [{ id: 'custom.width', value: 100 }, { id: 'displayName', value: 'pipeline' }, { id: 'links', value: [{ targetBlank: true, title: '${__value.raw}', url: '${__data.fields["pipeline_url"]}' }] }] },
          { matcher: { id: 'byName', options: 'job_id' }, properties: [{ id: 'custom.width', value: 100 }, { id: 'displayName', value: 'job' }, { id: 'links', value: [{ targetBlank: true, title: '${__value.raw}', url: '${__data.fields["job_url"]}' }] }] },
          { matcher: { id: 'byName', options: 'pipeline_url' }, properties: [{ id: 'custom.hidden', value: true }] },
          { matcher: { id: 'byName', options: 'job_url' }, properties: [{ id: 'custom.hidden', value: true }] },
        ],
      },
      options: { cellHeight: 'sm', showHeader: true },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
              f.created_at,
              f.project_path,
              f.job_name,
              b.pipeline_id,
              f.job_id,
              concat('https://gitlab.com/', f.project_path, '/-/pipelines/', toString(b.pipeline_id)) AS pipeline_url,
              concat('https://gitlab.com/', f.project_path, '/-/jobs/', toString(f.job_id)) AS job_url
            FROM ci_metrics.failure_analysis_metrics f
            JOIN ci_metrics.build_metrics b ON f.job_id = b.id
            WHERE $__timeFilter(f.created_at)
              AND (length('${project_path_var:pipe}') = 0 OR match(f.project_path, '^(${project_path_var:pipe})$'))
              AND (f.failure_category = '' OR f.failure_category = 'no_failure_category_found')
            ORDER BY f.created_at DESC
            LIMIT 200
          |||,
          refId: 'A',
        },
      ],
      gridPos: { x: 0, y: 86, w: 24, h: 10 },
    },
    {
      type: 'barchart',
      title: 'Top 20 failure categories by signature diversity',
      datasource: panels.clickHouseDatasource,
      description: 'Failure categories with the most unique signatures. High diversity means failures within that category are varied and harder to cluster — a signal that more granular signature matching may help.',
      fieldConfig: {
        defaults: {
          color: { mode: 'thresholds' },
          custom: {
            axisBorderShow: false,
            axisColorMode: 'text',
            axisPlacement: 'auto',
            fillOpacity: 88,
            gradientMode: 'hue',
            hideFrom: { legend: false, tooltip: false, viz: false },
            lineWidth: 1,
            scaleDistribution: { type: 'linear' },
            thresholdsStyle: { mode: 'off' },
          },
          mappings: [],
          thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] },
        },
        overrides: [],
      },
      options: {
        barRadius: 0,
        barWidth: 0.97,
        colorByField: 'unique_signatures',
        fullHighlight: false,
        groupWidth: 0.7,
        legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: false },
        orientation: 'horizontal',
        showValue: 'auto',
        stacking: 'none',
        tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
        xTickLabelRotation: 0,
        xTickLabelSpacing: 0,
      },
      pluginVersion: '12.3.1',
      targets: [
        {
          editorType: 'sql',
          format: 1,
          queryType: 'table',
          rawSql: |||
            SELECT
              failure_category,
              uniq(failure_signature) AS unique_signatures
            FROM ci_metrics.failure_analysis_metrics
            WHERE $__timeFilter(created_at)
              AND failure_category != ''
              AND failure_category != 'no_failure_category_found'
              AND failure_signature != ''
              AND (length('${project_path_var:pipe}') = 0 OR match(project_path, '^(${project_path_var:pipe})$'))
            GROUP BY failure_category
            ORDER BY unique_signatures DESC
            LIMIT 20
          |||,
          refId: 'A',
        },
      ],
      gridPos: { x: 0, y: 96, w: 24, h: 16 },
    },
  ]),
  gridPos={ x: 0, y: 53, w: 24, h: 1 },
)
