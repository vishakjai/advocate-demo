local githubObjectTypes = [
  'issue',
  'pull_request',
  'pull_request_merged_by',
  'pull_request_review',
  'milestone',
  'note',
  'diff_note',
  'label',
  'lfs_object',
  'release',
];

local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local rate(operation, objectType) =
  ('rate(github_importer_%s_%s{env="$environment"}[$__interval])' % [operation, objectType]);

local sum(metric) =
  ('(sum(%s) or vector(0))' % metric);

local projectsCountGraph() =
  panel.basic(
    datasource='$PROMETHEUS_DS',
    title='Projects successfully imported',
    legend_min=false,
    legend_max=false,
    legend_current=false,
    legend_total=true
  )
  .addTarget(
    target.prometheus(
      sum('github_importer_imported_projects_total'),
      legendFormat='Projects successfully imported'
    )
  );

local durationGraph() =
  panel.multiTimeSeries(
    title='Import Duration',
    description='Lower is better.',
    format='short',
    yAxisLabel='Duration',
    queries=std.map(
      function(p)
        {
          query: 'histogram_quantile(%(p)s, %(sum)s)' % {
            p: std.format('%.2f', p / 100),
            sum: ('sum(%s) by (le, environment)' % rate('total', 'duration_seconds_bucket')),
          },
          legendFormat: 'p%s' % p,
        },
      [50, 90, 95, 99]
    )
  );

local objectCounterGraph(title, queries) =
  panel.basic(
    title=title,
    legend_min=false,
    legend_max=false,
    legend_current=false,
    legend_total=true
  )
  .addTarget(
    target.prometheus(
      queries.fetched.query,
      legendFormat=queries.fetched.title
    )
  )
  .addTarget(
    target.prometheus(
      queries.imported.query,
      legendFormat=queries.imported.title
    )
  )
  .addTarget(
    target.prometheus(
      '(((%(fetched)s) - (%(imported)s)) * 3600) or vector(0)' % {
        fetched: queries.fetched.value,
        imported: queries.imported.value,
      },
      legendFormat='diff'
    )
  )
  .addSeriesOverride({
    alias: '/fetched.*/',
    color: '#3274D9',
  })
  .addSeriesOverride({
    alias: '/imported.*/',
    color: '#37872D',
  })
  .addSeriesOverride({
    alias: 'diff',
    color: '#E02F44',
  });

local githubObjectCounter(objectType) =
  objectCounterGraph(objectType, {
    fetched: {
      title: 'fetched %s' % objectType,
      value: sum(rate('fetched', objectType)),
      query: '%s * 3600' % self.value,
    },
    imported: {
      title: 'imported %s' % objectType,
      value: sum(rate('imported', objectType)),
      query: '%s * 3600' % self.value,
    },
  });

local totalGithubObjectCounter() =
  objectCounterGraph('Total Objects', {
    fetched: {
      title: 'fetched',
      value: std.join(' + ', std.map(
        function(objectType) sum(rate('fetched', objectType)),
        githubObjectTypes
      )),
      query: '(%s) * 3600' % self.value,
    },
    imported: {
      title: 'imported',
      value: std.join(' + ', std.map(
        function(objectType) sum(rate('imported', objectType)),
        githubObjectTypes
      )),
      query: '(%s) * 3600' % self.value,
    },
  });

basic.dashboard(
  'Github Importer',
  graphTooltip='shared_tooltip',
  tags=[
    'sidekiq',
    'managed',
    'group:import',
  ]
)
.addPanel(
  durationGraph(),
  gridPos={ x: 0, y: 0, w: 24, h: 13 }
)
.addPanels(
  layout.grid(
    [
      projectsCountGraph(),
      totalGithubObjectCounter(),
    ],
    cols=1,
    rowHeight=10,
    startRow=1
  )
)
.addPanels(
  layout.grid(
    std.map(githubObjectCounter, githubObjectTypes),
    cols=2,
    rowHeight=10,
    startRow=3
  )
)
