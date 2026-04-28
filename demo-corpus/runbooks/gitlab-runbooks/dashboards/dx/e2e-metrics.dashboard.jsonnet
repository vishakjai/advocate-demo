local config = import './common/config.libsonnet';
local panels = import './common/panels.libsonnet';
local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';

(basic.dashboard(
   'E2E pipeline metrics',
   tags=config.ciMetricsTags,
   includeEnvironmentTemplate=false,
   includeStandardEnvironmentAnnotations=false,
   includePrometheusDatasourceTemplate=false,
   time_from='now-30d',
   time_to='now',
   uid='dx-e2e-metrics',
 ) + { timezone: 'browser' })
.addPanel(
  panels.textPanel(|||
    # E2E test overview

    Graphs with various daily metrics related to E2E test execution in gitlab-org/gitlab

  |||),
  gridPos={ h: 3, w: 24, x: 0, y: 0 },
)
.addPanel(
  grafana.row.new(title='Pipeline overview', collapse=false),
  gridPos={ h: 1, w: 24, x: 0, y: 3 },
)
.addPanel(
  panels.textPanel(|||
    # Successful pipeline duration

    Total runtime for E2E test workflow. This includes environment build and deploy times as well as test execution.
  |||),
  gridPos={ h: 3, w: 24, x: 0, y: 4 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='CNG',
    rawSql=|||
      SELECT
          toStartOfDay(timestamp) AS time,
          quantile(0.9)(total_duration) AS p90,
          quantile(0.8)(total_duration) AS p80,
          quantile(0.5)(total_duration) AS p50,
          avg(total_duration) AS average
      FROM (
          SELECT
              p.id AS pipeline_id,
              p.created_at as timestamp,
              p.duration + b.duration AS total_duration
          FROM ci_metrics.finished_pipelines_mv AS p
          INNER JOIN ci_metrics.finished_builds_mv AS b
              ON p.id = b.pipeline_id
          WHERE
               $__timeFilter(p.created_at)
               AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
               AND p.name = 'E2E CNG'
              AND p.status = 'success'
              AND b.name = 'compile-production-assets'
              AND b.status = 'success'
      )
      GROUP BY time
      ORDER BY time
    |||,
    unit='s',
  ),
  gridPos={ h: 9, w: 24, x: 0, y: 7 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='GDK',
    rawSql=|||
      SELECT
          toStartOfDay(timestamp) AS time,
          quantile(0.9)(total_duration) AS p90,
          quantile(0.8)(total_duration) AS p80,
          quantile(0.5)(total_duration) AS p50,
          avg(total_duration) AS average
      FROM (
          SELECT
              p.id AS pipeline_id,
              p.created_at as timestamp,
              p.duration + b.duration AS total_duration
          FROM ci_metrics.finished_pipelines_mv AS p
          INNER JOIN ci_metrics.finished_builds_mv AS b
              ON p.id = b.pipeline_id
          WHERE
              $__timeFilter(p.created_at)
              AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
              AND p.name = 'E2E GDK'
              AND p.status = 'success'
              AND b.name = 'build-gdk-image'
              AND b.status = 'success'
      )
      GROUP BY time
      ORDER BY time
    |||,
    unit='s',
  ),
  gridPos={ h: 10, w: 12, x: 0, y: 16 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='OMNIBUS',
    rawSql=|||
      SELECT
          toStartOfDay(timestamp) AS time,
          quantile(0.9)(total_duration) AS p90,
          quantile(0.8)(total_duration) AS p80,
          quantile(0.5)(total_duration) AS p50,
          avg(total_duration) AS average
      FROM (
          SELECT
              p.id AS pipeline_id,
              p.created_at as timestamp,
              p.duration + b.duration AS total_duration
          FROM ci_metrics.finished_pipelines_mv AS p
          INNER JOIN ci_metrics.finished_builds_mv AS b
              ON p.id = b.pipeline_id
          WHERE
              $__timeFilter(p.created_at)
              AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
              AND p.name = 'E2E Omnibus GitLab EE'
              AND p.status = 'success'
              AND b.name = 'compile-production-assets'
              AND b.status = 'success'
      )
      GROUP BY time
      ORDER BY time
    |||,
    unit='s',
  ),
  gridPos={ h: 10, w: 12, x: 12, y: 16 },
)
.addPanel(
  panels.textPanel('# Failure rate'),
  gridPos={ h: 2, w: 24, x: 0, y: 26 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='Master pipeline failure rate',
    rawSql=|||
      SELECT
          toStartOfDay(created_at) AS time,
          countIf(status = 'failed' AND name = 'E2E CNG') * 100.0 / nullIf(countIf(name = 'E2E CNG'), 0) AS cng,
          countIf(status = 'failed' AND name = 'E2E GDK') * 100.0 / nullIf(countIf(name = 'E2E GDK'), 0) AS gdk
      FROM ci_metrics.finished_pipelines_mv
      WHERE
          $__timeFilter(created_at)
          AND project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
          AND name IN ('E2E CNG', 'E2E GDK', 'E2E Omnibus GitLab EE')
          AND ref = 'master'
          AND status != 'canceled'
      GROUP BY time
      ORDER BY time
    |||,
    unit='percent',
  ),
  gridPos={ h: 9, w: 12, x: 0, y: 28 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='Merge request pipeline failure rate',
    rawSql=|||
      SELECT
          toStartOfDay(created_at) AS time,
          countIf(status = 'failed' AND name = 'E2E CNG') * 100.0 / nullIf(countIf(name = 'E2E CNG'), 0) AS cng,
          countIf(status = 'failed' AND name = 'E2E GDK') * 100.0 / nullIf(countIf(name = 'E2E GDK'), 0) AS gdk
      FROM ci_metrics.finished_pipelines_mv
      WHERE
          $__timeFilter(created_at)
          AND project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
          AND name IN ('E2E CNG', 'E2E GDK')
          AND is_merge_request = true
          AND status != 'canceled'
      GROUP BY time
      ORDER BY time
    |||,
    unit='percent',
  ),
  gridPos={ h: 9, w: 12, x: 12, y: 28 },
)
.addPanel(
  panels.textPanel('# Counts'),
  gridPos={ h: 2, w: 24, x: 0, y: 37 },
)
.addPanel(
  panels.timeSeriesPanel(
    title='Pipeline executions',
    rawSql=|||
      SELECT
          toStartOfDay(created_at) AS time,
          countIf(name = 'E2E CNG') AS cng,
          countIf(name = 'E2E GDK') AS gdk,
          countIf(name = 'E2E Omnibus GitLab EE') as omnibus
      FROM ci_metrics.finished_pipelines_mv
      WHERE
          $__timeFilter(created_at)
          AND project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
          AND name IN ('E2E CNG', 'E2E GDK', 'E2E Omnibus GitLab EE')
      GROUP BY time
      ORDER BY time
    |||,
    unit='short',
  ),
  gridPos={ h: 9, w: 24, x: 0, y: 39 },
)
.addPanel(
  grafana.row.new(title='Environment builds', collapse=true)
  .addPanel(
    panels.textPanel('Build times for jobs related to preparation of system under test'),
    gridPos={ h: 2, w: 24, x: 0, y: 49 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='compile-production-assets',
      rawSql=|||
        SELECT
            toStartOfDay(created_at) AS time,
            quantile(0.9)(duration) AS p90,
            quantile(0.8)(duration) AS p80,
            quantile(0.5)(duration) AS p50,
            avg(duration) AS average
        FROM ci_metrics.finished_builds_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
            AND name = 'compile-production-assets'
            AND status = 'success'
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 8, w: 12, x: 0, y: 98 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='cng-build',
      rawSql=|||
        SELECT
            toStartOfDay(created_at) AS time,
            quantile(0.9)(duration) AS p90,
            quantile(0.8)(duration) AS p80,
            quantile(0.5)(duration) AS p50,
            avg(duration) AS average
        FROM ci_metrics.finished_pipelines_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = 'gitlab-org/build/CNG-mirror'
            AND status = 'success'
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ) + { description: 'All cng component builds' },
    gridPos={ h: 8, w: 12, x: 12, y: 98 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='omnibus-build',
      rawSql=|||
        SELECT
            toStartOfDay(created_at) AS time,
            quantile(0.9)(duration) AS p90,
            quantile(0.8)(duration) AS p80,
            quantile(0.5)(duration) AS p50,
            avg(duration) AS average
        FROM ci_metrics.finished_pipelines_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = 'gitlab-org/build/omnibus-gitlab-mirror'
            AND status = 'success'
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ) + { description: 'Omnibus docker image build' },
    gridPos={ h: 8, w: 12, x: 0, y: 106 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='build-gdk-image',
      rawSql=|||
        SELECT
            toStartOfDay(created_at) AS time,
            quantile(0.9)(duration) AS p90,
            quantile(0.8)(duration) AS p80,
            quantile(0.5)(duration) AS p50,
            avg(duration) AS average
        FROM ci_metrics.finished_builds_mv
        WHERE
            $__timeFilter(created_at)
            AND project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
            AND name = 'build-gdk-image'
            AND status = 'success'
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 8, w: 12, x: 12, y: 106 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 48 },
)
.addPanel(
  grafana.row.new(title='Test job data', collapse=true)
  .addPanel(
    panels.textPanel('# Test job counts\n\n'),
    gridPos={ h: 2, w: 24, x: 0, y: 50 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='CNG',
      rawSql=|||
        SELECT
            toStartOfDay(timestamp) AS time,
            quantile(0.9)(build_count) AS p90,
            quantile(0.8)(build_count) AS p80,
            quantile(0.5)(build_count) AS p50,
            avg(build_count) AS average
        FROM (
            SELECT
                p.id,
                p.created_at as timestamp,
                count() AS build_count
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E CNG'
                AND b.stage = 'test'
            GROUP BY p.id, p.created_at
        )
        GROUP BY time
        ORDER BY time
      |||,
      unit='short',
    ) + { description: 'Job count in test stage within a single pipeline run' },
    gridPos={ h: 8, w: 24, x: 0, y: 52 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='GDK',
      rawSql=|||
        SELECT
            toStartOfDay(timestamp) AS time,
            quantile(0.9)(build_count) AS p90,
            quantile(0.8)(build_count) AS p80,
            quantile(0.5)(build_count) AS p50,
            avg(build_count) AS average
        FROM (
            SELECT
                p.id,
                p.created_at as timestamp,
                count() AS build_count
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E GDK'
                AND b.stage = 'test'
            GROUP BY p.id, p.created_at
        )
        GROUP BY time
        ORDER BY time
      |||,
      unit='short',
    ) + { description: 'Job count in test stage within a single pipeline run' },
    gridPos={ h: 8, w: 12, x: 0, y: 60 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='OMNIBUS',
      rawSql=|||
        SELECT
            toStartOfDay(timestamp) AS time,
            quantile(0.9)(build_count) AS p90,
            quantile(0.8)(build_count) AS p80,
            quantile(0.5)(build_count) AS p50,
            avg(build_count) AS average
        FROM (
            SELECT
                p.id,
                p.created_at as timestamp,
                count() AS build_count
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E Omnibus GitLab EE'
                AND b.stage = 'test'
            GROUP BY p.id, p.created_at
        )
        GROUP BY time
        ORDER BY time
      |||,
      unit='short',
    ) + { description: 'Job count in test stage within a single pipeline run' },
    gridPos={ h: 8, w: 12, x: 12, y: 60 },
  )
  .addPanel(
    panels.textPanel('# Test job duration\n\n'),
    gridPos={ h: 2, w: 24, x: 0, y: 68 },
  )
  .addPanel(
    (panels.timeSeriesPanel(
       title='CNG',
       unit='s',
     )) + {
      targets: [
        {
          editorType: 'sql',
          format: 1,

          pluginVersion: '4.11.4',
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfDay(p.created_at) AS time,
                quantile(0.9)(b.duration) AS p90,
                quantile(0.8)(b.duration) AS p80,
                quantile(0.5)(b.duration) AS p50,
                avg(b.duration) AS average
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E CNG'
                AND b.stage = 'test'
                AND b.status = 'success'
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
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
                toStartOfDay(p.created_at) AS time,
                quantile(0.8)(b.duration) AS p80_failed,
                quantile(0.5)(b.duration) AS p50_failed
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E CNG'
                AND b.stage = 'test'
                AND b.status = 'failed'
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'B',
        },
      ],
    },
    gridPos={ h: 8, w: 24, x: 0, y: 70 },
  )
  .addPanel(
    (panels.timeSeriesPanel(
       title='GDK',
       unit='s',
     )) + {
      targets: [
        {
          editorType: 'sql',
          format: 1,

          pluginVersion: '4.11.4',
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfDay(p.created_at) AS time,
                quantile(0.9)(b.duration) AS p90,
                quantile(0.8)(b.duration) AS p80,
                quantile(0.5)(b.duration) AS p50,
                avg(b.duration) AS average
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E GDK'
                AND b.stage = 'test'
                AND b.status = 'success'
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
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
                toStartOfDay(p.created_at) AS time,
                quantile(0.8)(b.duration) AS p80_failed,
                quantile(0.5)(b.duration) AS p50_failed
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E GDK'
                AND b.stage = 'test'
                AND b.status = 'failed'
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'B',
        },
      ],
    },
    gridPos={ h: 8, w: 12, x: 0, y: 78 },
  )
  .addPanel(
    (panels.timeSeriesPanel(
       title='OMNIBUS',
       unit='s',
     )) + {
      targets: [
        {
          editorType: 'sql',
          format: 1,

          pluginVersion: '4.11.4',
          queryType: 'table',
          rawSql: |||
            SELECT
                toStartOfDay(p.created_at) AS time,
                quantile(0.9)(b.duration) AS p90,
                quantile(0.8)(b.duration) AS p80,
                quantile(0.5)(b.duration) AS p50,
                avg(b.duration) AS average
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E Omnibus GitLab EE'
                AND b.stage = 'test'
                AND b.status = 'success'
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'A',
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
                toStartOfDay(p.created_at) AS time,
                quantile(0.8)(b.duration) AS p80_failed,
                quantile(0.5)(b.duration) AS p50_failed
            FROM ci_metrics.finished_pipelines_mv AS p
            INNER JOIN ci_metrics.finished_builds_mv AS b
                ON p.original_id = b.pipeline_id
            WHERE
                $__timeFilter(p.created_at)
                AND p.project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND p.name = 'E2E Omnibus GitLab EE'
                AND b.stage = 'test'
                AND b.status = 'failed'
            GROUP BY time
            ORDER BY time
          |||,
          refId: 'B',
        },
      ],
    },
    gridPos={ h: 8, w: 12, x: 12, y: 78 },
  )
  .addPanel(
    panels.textPanel('# Parallel runtime variance\n\nRuntime variance between slowest and fastest parallel job of main test suite. This indicates knapsack parallelisation distribution effectiveness.'),
    gridPos={ h: 3, w: 24, x: 0, y: 86 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='cng-instance',
      rawSql=|||
        SELECT
            toStartOfDay(timestamp) AS time,
            quantile(0.9)(runtime_variance) AS p90,
            quantile(0.8)(runtime_variance) AS p80,
            quantile(0.5)(runtime_variance) AS p50,
            avg(runtime_variance) AS average
        FROM (
            SELECT
                pipeline_id,
                min(created_at) AS timestamp,
                max(duration) - min(duration) AS runtime_variance
            FROM ci_metrics.finished_builds_mv
            WHERE
                $__timeFilter(created_at)
                AND project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND name LIKE '%cng-instance%'
                AND status = 'success'
            GROUP BY pipeline_id
            HAVING count() > 1
        )
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 8, w: 12, x: 0, y: 89 },
  )
  .addPanel(
    panels.timeSeriesPanel(
      title='gdk-instance',
      rawSql=|||
        SELECT
            toStartOfDay(timestamp) AS time,
            quantile(0.9)(runtime_variance) AS p90,
            quantile(0.8)(runtime_variance) AS p80,
            quantile(0.5)(runtime_variance) AS p50,
            avg(runtime_variance) AS average
        FROM (
            SELECT
                pipeline_id,
                min(created_at) AS timestamp,
                max(duration) - min(duration) AS runtime_variance
            FROM ci_metrics.finished_builds_mv
            WHERE
                $__timeFilter(created_at)
                AND project_path = 'gitlab-org/gitlab' -- E2E tests run only in gitlab-org/gitlab
                AND name LIKE 'gdk-instance%'
                AND status = 'success'
            GROUP BY pipeline_id
            HAVING count() > 1
        )
        GROUP BY time
        ORDER BY time
      |||,
      unit='s',
    ),
    gridPos={ h: 8, w: 12, x: 12, y: 89 },
  ),
  gridPos={ h: 1, w: 24, x: 0, y: 49 },
)
