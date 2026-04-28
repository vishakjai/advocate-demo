local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local template = grafana.template;
local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local row = grafana.row;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';

local totalBlockersCount = 'max by (week, root_cause) (last_over_time(delivery_deployment_blocker_count{root_cause=~".+", root_cause!="RootCause::FlakyTest"}[1d])) != 0';
local totalGprdHoursBlocked = 'max by (week, root_cause) (last_over_time(delivery_deployment_hours_blocked{root_cause=~".+", root_cause!="RootCause::FlakyTest", target_env="gprd"}[1d])) != 0';
local totalGstgHoursBlocked = 'max by (week, root_cause) (last_over_time(delivery_deployment_hours_blocked{root_cause=~".+", root_cause!="RootCause::FlakyTest", target_env="gstg"}[1d])) != 0';
local blockersCount = 'max by (week, root_cause) (last_over_time(delivery_deployment_blocker_count{root_cause="$root_cause"}[1d]))';
local gprdHoursBlocked = 'max by (week, root_cause) (last_over_time(delivery_deployment_hours_blocked{root_cause="$root_cause", target_env="gprd"}[1d]))';
local gstgHoursBlocked = 'max by (week, root_cause) (last_over_time(delivery_deployment_hours_blocked{root_cause="$root_cause", target_env="gstg"}[1d]))';

local textPanel =
  g.panel.text.new('')
  + g.panel.text.options.withMode('markdown')
  + g.panel.text.options.withContent(|||
    # Deployment Blockers

    Deployment failures are currently automatically captured under [release/tasks issues](https://gitlab.com/gitlab-org/release/tasks/-/issues).
    Each week a report is generated to keep track of the deployment blockers of the GitLab.com environments, release managers are responsible for labeling these failures with appropriate `RootCause::*` labels

    This dashboard tracks the trend of recurring root causes for deployment blockers. Each root cause is displayed in separate rows with three panels: one for the count of blockers, one for `gprd` hours blocked, and one for `gstg` hours blocked. At the top, there is an overview of the failure types, including the total calculations for the entire specified time window.

    Links:
    - [List of root causes](https://gitlab.com/gitlab-org/release/tasks/-/labels?subscribed=&sort=relevance&search=RootCause)
    - [Deployments metrics review](https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/1192)
  |||);

local barChartPanel(title, name, query) =
  g.panel.barChart.new(title)
  + g.panel.barChart.options.withOrientation('horizontal')
  + g.panel.barChart.options.legend.withDisplayMode('table')
  + g.panel.barChart.options.legend.withShowLegend(true)
  + g.panel.barChart.options.legend.withPlacement('bottom')
  + g.panel.barChart.options.legend.withCalcs(['sum'])
  + g.panel.barChart.standardOptions.withDisplayName(name)
  + g.panel.barChart.standardOptions.color.withMode('thresholds')
  + g.panel.barChart.standardOptions.thresholds.withMode('absolute')
  + g.panel.barChart.standardOptions.thresholds.withSteps([
    {
      value: null,
      color: 'green',
    },
  ])
  + g.panel.barChart.queryOptions.withTargetsMixin([
    g.query.prometheus.new(
      '$PROMETHEUS_DS',
      query,
    )
    + g.query.prometheus.withFormat('table')
    + g.query.prometheus.withLegendFormat('{{root_cause}}'),
  ])
  + g.panel.barChart.queryOptions.withTransformations([
    g.panel.barChart.queryOptions.transformation.withId('groupBy')
    + g.panel.barChart.queryOptions.transformation.withOptions({
      fields: {
        week: {
          aggregations: [],
          operation: 'groupby',
        },
        root_cause: {
          aggregations: [],
          operation: 'groupby',
        },
        Value: {
          aggregations: [
            'lastNotNull',
          ],
          operation: 'aggregate',
        },
      },
    }),
    g.panel.barChart.queryOptions.transformation.withId('groupBy')
    + g.panel.barChart.queryOptions.transformation.withOptions({
      fields: {
        root_cause: {
          aggregations: [],
          operation: 'groupby',
        },
        'Value (lastNotNull)': {
          aggregations: [
            'sum',
          ],
          operation: 'aggregate',
        },
      },
    }),
  ]);

local trendPanel(title, query, name) =
  g.panel.trend.new(title)
  + g.panel.trend.options.withXField('week_index')
  + g.panel.trend.options.legend.withDisplayMode('list')
  + g.panel.trend.options.legend.withPlacement('bottom')
  + g.panel.trend.fieldConfig.defaults.custom.withDrawStyle('line')
  + g.panel.trend.fieldConfig.defaults.custom.withLineInterpolation('linear')
  + g.panel.trend.fieldConfig.defaults.custom.withLineWidth(1)
  + g.panel.trend.fieldConfig.defaults.custom.withShowPoints('always')
  + g.panel.trend.fieldConfig.defaults.custom.withSpanNulls(true)
  + g.panel.trend.fieldConfig.defaults.custom.withAxisBorderShow(true)
  + g.panel.trend.standardOptions.withDisplayName(name)
  + g.panel.trend.standardOptions.withDecimals(0)
  + g.panel.trend.standardOptions.withUnit('short')
  + g.panel.trend.standardOptions.color.withMode('palette-classic')
  + g.panel.trend.standardOptions.thresholds.withMode('absolute')
  + g.panel.trend.standardOptions.thresholds.withSteps([
    {
      value: null,
      color: 'green',
    },
  ])
  + g.panel.trend.standardOptions.withOverrides([
    g.panel.trend.standardOptions.override.byName.new('week_index')
    + g.panel.trend.standardOptions.override.byName.withPropertiesFromOptions(
      g.panel.trend.fieldConfig.defaults.custom.withAxisLabel('week_index')
      + g.panel.trend.fieldConfig.defaults.custom.withAxisPlacement('hidden')
    ),
  ])
  + g.panel.trend.queryOptions.withTargetsMixin([
    g.query.prometheus.new(
      '$PROMETHEUS_DS',
      query,
    )
    + g.query.prometheus.withFormat('table'),
  ])
  + g.panel.trend.queryOptions.withTransformations([
    g.panel.trend.queryOptions.transformation.withId('groupBy')
    + g.panel.trend.queryOptions.transformation.withOptions({
      fields: {
        week: {
          aggregations: [],
          operation: 'groupby',
        },
        root_cause: {
          aggregations: [],
          operation: null,
        },
        Value: {
          aggregations: [
            'last',
          ],
          operation: 'aggregate',
        },
      },
    }),
    g.panel.trend.queryOptions.transformation.withId('calculateField')
    + g.panel.trend.queryOptions.transformation.withOptions({
      alias: 'count',
      binary: {
        left: 'week',
      },
      mode: 'index',
      reduce: {
        reducer: 'sum',
      },
    }),
    g.panel.trend.queryOptions.transformation.withId('calculateField')
    + g.panel.trend.queryOptions.transformation.withOptions({
      alias: 'week_index',
      binary: {
        left: 'count',
        right: '1',
      },
      mode: 'binary',
      reduce: {
        reducer: 'sum',
      },
    }),
    g.panel.trend.queryOptions.transformation.withId('organize')
    + g.panel.trend.queryOptions.transformation.withOptions({
      excludeByName: {
        Time: false,
        count: true,
      },
      includeByName: {},
      indexByName: {},
      renameByName: {},
    }),
  ]);

local tablePanel =
  g.panel.table.new('')
  + g.panel.table.fieldConfig.defaults.custom.withFilterable(true)
  + g.panel.table.options.withShowHeader(true)
  + g.panel.table.standardOptions.color.withMode('thresholds')
  + g.panel.table.queryOptions.withTargetsMixin([
    g.query.prometheus.new(
      '$PROMETHEUS_DS',
      blockersCount,
    )
    + g.query.prometheus.withFormat('table'),

    g.query.prometheus.new(
      '$PROMETHEUS_DS',
      gprdHoursBlocked,
    )
    + g.query.prometheus.withFormat('table'),

    g.query.prometheus.new(
      '$PROMETHEUS_DS',
      gstgHoursBlocked,
    )
    + g.query.prometheus.withFormat('table'),

  ])
  + g.panel.table.queryOptions.withTransformations([
    g.panel.table.queryOptions.transformation.withId('merge')
    + g.panel.table.queryOptions.transformation.withOptions({}),
    g.panel.table.queryOptions.transformation.withId('sortBy')
    + g.panel.table.queryOptions.transformation.withOptions({
      fields: {},
      sort: [
        {
          field: 'week',
        },
      ],
    }),
    g.panel.table.queryOptions.transformation.withId('groupBy')
    + g.panel.table.queryOptions.transformation.withOptions({
      fields: {
        'Value #A': {
          aggregations: [
            'lastNotNull',
          ],
          operation: 'aggregate',
        },
        'Value #B': {
          aggregations: [
            'lastNotNull',
          ],
          operation: 'aggregate',
        },
        'Value #C': {
          aggregations: [
            'lastNotNull',
          ],
          operation: 'aggregate',
        },
        root_cause: {
          aggregations: [],
          operation: 'groupby',
        },
        week: {
          aggregations: [],
          operation: 'groupby',
        },
      },
    }),
    g.panel.table.queryOptions.transformation.withId('groupBy')
    + g.panel.table.queryOptions.transformation.withOptions({
      fields: {
        'Value #A': {
          aggregations: [
            'sum',
          ],
          operation: 'aggregate',
        },
        'Value #A (lastNotNull)': {
          aggregations: [
            'sum',
          ],
          operation: 'aggregate',
        },
        'Value #B': {
          aggregations: [
            'sum',
          ],
          operation: 'aggregate',
        },
        'Value #B (lastNotNull)': {
          aggregations: [
            'sum',
          ],
          operation: 'aggregate',
        },
        'Value #C': {
          aggregations: [
            'sum',
          ],
          operation: 'aggregate',
        },
        'Value #C (lastNotNull)': {
          aggregations: [
            'sum',
          ],
          operation: 'aggregate',
        },
        root_cause: {
          aggregations: [],
          operation: 'aggregate',
        },
        week: {
          aggregations: [],
          operation: 'groupby',
        },
        week_index: {
          aggregations: [],
        },
      },
    }),
    g.panel.table.queryOptions.transformation.withId('calculateField')
    + g.panel.table.queryOptions.transformation.withOptions({
      alias: 'count',
      mode: 'index',
      reduce: {
        reducer: 'sum',
      },
    }),
    g.panel.table.queryOptions.transformation.withId('calculateField')
    + g.panel.table.queryOptions.transformation.withOptions({
      alias: 'week_index',
      binary: {
        left: 'count',
        right: '1',
      },
      mode: 'binary',
      reduce: {
        reducer: 'sum',
      },
    }),
    g.panel.table.queryOptions.transformation.withId('organize')
    + g.panel.table.queryOptions.transformation.withOptions({
      excludeByName: {
        count: true,
      },
      includeByName: {},
      indexByName: {},
      renameByName: {
        'Value #A (lastNotNull) (sum)': 'blockers_count',
        'Value #A (sum)': 'blockers_count',
        'Value #B (lastNotNull) (sum)': 'gprd_hours_blocked',
        'Value #B (sum)': 'gprd_hours_blocked',
        'Value #C (lastNotNull) (sum)': 'gstg_hours_blocked',
        'Value #C (sum)': 'gstg_hours_blocked',
      },
    }),
  ]);

basic.dashboard(
  'Deployment Blockers',
  tags=['release'],
  editable=true,
  time_from='now-90d',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-ops'),
)
.addTemplate(
  template.new(
    'root_cause',
    '$PROMETHEUS_DS',
    'query_result(max by (root_cause) (last_over_time(delivery_deployment_blocker_count{root_cause!="RootCause::FlakyTest"}[$__range]) > 0))',
    includeAll=true,
    multi=true,
    sort=1,
    regex='/root_cause="(?<text>[^"]+)/g',
  )
)
.addPanel(textPanel, gridPos={ x: 0, y: 0, w: 24, h: 7 })
.addPanel(
  row.new(title='Overview'),
  gridPos={ x: 0, y: 7, w: 24, h: 1 },
)
.addPanel(barChartPanel('Total Blockers Count per Root Cause', 'blockers_count', totalBlockersCount), gridPos={ x: 0, y: 8, w: 8, h: 10 })
.addPanel(barChartPanel('Total gprd Hours Blocked per Root Cause', 'gprd_hours_blocked', totalGprdHoursBlocked), gridPos={ x: 8, y: 8, w: 8, h: 10 })
.addPanel(barChartPanel('Total gstg Hours Blocked per Root Cause', 'gstg_hours_blocked', totalGstgHoursBlocked), gridPos={ x: 16, y: 8, w: 8, h: 10 })
.addPanel(
  row.new(title='$root_cause', repeat='root_cause'),
  gridPos={ x: 0, y: 18, w: 24, h: 1 },
)
.addPanel(trendPanel('Blockers Count for $root_cause', blockersCount, 'blockers_count'), gridPos={ x: 0, y: 19, w: 8, h: 9 })
.addPanel(trendPanel('gprd Hours Blocked for $root_cause', gprdHoursBlocked, 'gprd_hours_blocked'), gridPos={ x: 8, y: 19, w: 8, h: 9 })
.addPanel(trendPanel('gstg Hours Blocked for $root_cause', gstgHoursBlocked, 'gstg_hours_blocked'), gridPos={ x: 16, y: 19, w: 8, h: 9 })
.addPanel(tablePanel, gridPos={ x: 0, y: 28, w: 24, h: 7 })
.addPanel(row.new(''), gridPos={ x: 0, y: 100000, w: 24, h: 1 })
.trailer()
