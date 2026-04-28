local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local timepickerlib = import 'github.com/grafana/grafonnet-lib/grafonnet/timepicker.libsonnet';
local prometheus = grafana.prometheus;
local promQuery = import 'grafana/prom_query.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local annotation = grafana.annotation;
local statPanel = grafana.statPanel;
local textPanel = grafana.text;
local row = grafana.row;
local colorScheme = import 'grafana/color_scheme.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';

// This is the height of a single cell in Column 1 which shows the version that is currently running
// in each environment.
local singleCellHeight = 3;

local environments = [
  {
    id: 'gprd',
    name: 'Production',
    role: 'gprd',
    stage: 'main',
    icon: '🚀',
    datasource: mimirHelper.mimirDatasource('gitlab-gprd'),
  },
  {
    id: 'gprd-cny',
    name: 'Canary',
    role: 'gprd',
    stage: 'cny',
    icon: '🐤',
    datasource: mimirHelper.mimirDatasource('gitlab-gprd'),
  },
  {
    id: 'gstg',
    name: 'Staging',
    role: 'gstg',
    stage: 'main',
    icon: '🏗',
    datasource: mimirHelper.mimirDatasource('gitlab-gstg'),
  },
  {
    id: 'gstg-cny',
    name: 'Staging Canary',
    role: 'gstg',
    stage: 'cny',
    icon: '🐣',
    datasource: mimirHelper.mimirDatasource('gitlab-gstg'),
  },
];

local annotations = [
  annotation.datasource(
    'Production deploys',
    '-- Grafana --',
    enable=true,
    iconColor='#19730E',
    tags=['deploy', 'gprd'],
  ),
  annotation.datasource(
    'Canary deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#E08400',
    tags=['deploy', 'gprd-cny'],
  ),
  annotation.datasource(
    'Staging deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#5794F2',
    tags=['deploy', 'gstg'],
  ),
  annotation.datasource(
    'Staging Canary deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#8F3BB8',
    tags=['deploy', 'gstg-cny'],
  ),
  annotation.datasource(
    'Staging Ref deploys',
    '-- Grafana --',
    enable=false,
    iconColor='#EB0010',
    tags=['deploy', 'gstg-ref'],
  ),
  annotation.datasource(
    'Staging PDM',
    '-- Grafana --',
    enable=false,
    iconColor='#73BF69',
    tags=['pdm', 'gstg'],
  ),
  annotation.datasource(
    'Production PDM',
    '-- Grafana --',
    enable=false,
    iconColor='#FF9830',
    tags=['pdm', 'gprd'],
  ),
];

local buildPressureProjects = 'omnibus-gitlab-ee|cng-ee|gitlab-ee|gitaly|gitlab_kas';

local packageVersion(environment) =
  prometheus.target(
    |||
      topk(1, count(
        omnibus_build_info{environment="%(env)s", stage="%(stage)s", type="gitaly"}
      ) by (version))
    ||| % { env: environment.role, stage: environment.stage },
    instant=true,
    format='table',
    legendFormat='{{version}}',
  );

local environmentPressurePanel(environment) =
  panel.basic(
    '%s Auto-deploy pressure' % [environment.icon],
    legend_show=false,
  )
  .addYaxis(
    min=0,
    label='Commits',
  )
  .addSeriesOverride({
    alias: 'Commits',
    color: 'semi-dark-purple',
  })
  .addTarget(
    prometheus.target(
      'delivery_auto_deploy_pressure{job="delivery-metrics", role="%(role)s"}' % { role: environment.id },
      legendFormat='Commits',
    )
  );

// Stat panel used by top-level Auto-deploy Pressure
local
  deliveryStatPanel(
    title,
    description='',
    query='',
    legendFormat='',
    thresholdsMode='absolute',
    thresholds={},
    links=[],
    datasource='$PROMETHEUS_DS',
  ) =
    statPanel.new(
      title,
      description=description,
      allValues=false,
      decimals=0,
      min=0,
      colorMode='value',
      graphMode='area',
      justifyMode='auto',
      orientation='horizontal',
      reducerFunction='lastNotNull',
      thresholdsMode=thresholdsMode,
      datasource=datasource,
    )
    .addLinks(links)
    .addThresholds(thresholds)
    .addTarget(
      promQuery.target(
        query,
        legendFormat=legendFormat
      )
    );

// Bar Gauge panel used by top-level Release pressure (based on pick labels)
local bargaugePanel(
  title,
  description='',
  query='',
  legendFormat='',
  thresholds={},
  links=[],
  fieldLinks=[],
  orientation='horizontal',
  datasource='$PROMETHEUS_DS',
      ) =
  {
    description: description,
    fieldConfig: {
      values: false,
      defaults: {
        min: 0,
        max: 25,
        thresholds: thresholds,
        links: fieldLinks,
      },
    },
    links: links,
    options: {
      displayMode: 'basic',
      orientation: orientation,
      showUnfilled: true,
    },
    pluginVersion: '7.0.3',
    targets: [promQuery.target(query, legendFormat=legendFormat, instant=true)],
    title: title,
    type: 'bargauge',
    datasource: datasource,
  };

local pendingPDMMetricPanel(
  environment,
  datasource,
      ) = statPanel.new(
  '%s - Pending PDM' % environment,
  description=|||
    The pending PDM count for `%s` will be shown only when there was at least one deployment to the main stage of `%s` during the selected time period.

    If no value is shown here, select a longer time period.
  ||| % [environment, environment],
  allValues=false,
  noValue='Select a longer time period',
  decimals=0,
  min=0,
  colorMode='value',
  textMode='value_and_name',
  graphMode='area',
  justifyMode='auto',
  orientation='horizontal',
  reducerFunction='lastNotNull',
  thresholdsMode='absolute',
  datasource=datasource,
)
          .addThresholds([
  { color: colorScheme.normalRangeColor, value: null },
  { color: colorScheme.warningColor, value: 3 },
  { color: colorScheme.errorColor, value: 4 },
  { color: colorScheme.criticalColor, value: 5 },
])
          .addTarget(
  promQuery.target(
    // Metric collected from Kubernetes pod running Migrations
    // This metric is submitted for a short period of time, while the pod is alive.
    //
    // The fqdn="" filter excludes data from the metric of the same name which is submitted by the Deploy VM
    //
    // The pod="" filter excludes an earlier version of this metric which included a "pod" label. This label
    // has been removed now, so we don't want to rely on the old data anymore.
    'last_over_time(delivery_metrics_pending_migrations_total{env="%s",fqdn="",stage="main",pod=""}[$__range]) / 3' % environment,
    legendFormat='{{env}}',
  )
) + {
  gridPos+: {
    h: 2 * singleCellHeight,
  },
};

basic.dashboard(
  'Release Management',
  tags=['release'],
  editable=true,
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-ops'),
)
.addAnnotations(annotations)

// ----------------------------------------------------------------------------
// Summary
// ----------------------------------------------------------------------------

.addPanel(
  row.new(title='Summary'),
  gridPos={ x: 0, y: 0, w: 24, h: 12 },
)
.addPanels(
  layout.splitColumnGrid([
    [
      textPanel.new(
        title='',
        content=|||
          Package versions on each environment
        |||
      ),
    ],
    [
      textPanel.new(
        title='',
        content=|||
          Build pressure

          The number of commits in `master` not yet included in a package.
        |||
      ),
    ],
    [
      textPanel.new(
        title='',
        content=|||
          Deploy pressure

          The number of commits in `master` not yet deployed to each environment.
        |||
      ),
    ],
    [
      textPanel.new(
        title='',
        content=|||
          Patch release pressure: S1/S2

          Number of S1/S2 merge requests merged in previous releases.
        |||
      ),
    ],
    [
      textPanel.new(
        title='',
        content=|||
          Patch release pressure: Total

          Number of merge requests merged in previous releases regardless of severity.
        |||
      ),
    ],
    [
      textPanel.new(
        title='',
        content=|||
          Pending post deployment migrations

          The number of post deployment migrations pending execution in each environment.

          If there were no deployments to the main stage of `gstg` or `gprd`, the corresponding pending PDM count will not be displayed.

          Please select a longer time period for the dashboard to see the last submitted value.

          This metric is collected from Kubernetes.
        |||
      ),
    ],
  ], cellHeights=[5], startRow=1)
)
.addPanels(
  layout.splitColumnGrid([
    // Column 1: package versions
    [
      statPanel.new(
        '%s %s' % [environment.icon, environment.id],
        description='Package running on %s.' % [environment.name],
        reducerFunction='lastNotNull',
        fields='/^version$/',
        colorMode='none',
        graphMode='none',
        textMode='value',
        unit='String',
        datasource=environment.datasource,
      )
      .addTarget(packageVersion(environment))
      for environment in environments
    ],
    // Column 2: auto-deploy pressure
    [
      // Auto-build pressure
      deliveryStatPanel(
        'Auto-build pressure',
        description='The number of commits in `master` not yet included in a package.',
        query='max(delivery_auto_build_pressure{project_name=~"%(projects)s"}) by (project_name)' % { projects: buildPressureProjects },
        legendFormat='{{project_name}}',
        thresholds=[
          { color: colorScheme.normalRangeColor, value: null },
          { color: colorScheme.warningColor, value: 50 },
          { color: colorScheme.errorColor, value: 100 },
          { color: colorScheme.criticalColor, value: 150 },
        ],
        links=[
          {
            targetBlank: true,
            title: 'Latest commits',
            url: 'https://gitlab.com/gitlab-org/gitlab/commits/master',
          },
        ],
      ),
    ],
    // Column 3: auto-deploy pressure
    [
      // Auto-deploy pressure
      deliveryStatPanel(
        'Auto-deploy pressure',
        description='The number of commits in `master` not yet deployed to each environment.',
        query='max(delivery_auto_deploy_pressure{job="delivery-metrics"}) by (role)',
        legendFormat='{{role}}',
        thresholds=[
          { color: colorScheme.normalRangeColor, value: null },
          { color: colorScheme.warningColor, value: 50 },
          { color: colorScheme.errorColor, value: 100 },
          { color: colorScheme.criticalColor, value: 150 },
        ],
        links=[
          {
            targetBlank: true,
            title: 'Latest commits',
            url: 'https://gitlab.com/gitlab-org/gitlab/commits/master',
          },
        ],
      ),
    ],
    // Column 4: S1/S2 Patch release pressure
    [
      bargaugePanel(
        'Patch release pressure: S1/S2',
        description='Number of S1/S2 merge requests merged in previous releases.',
        query=|||
          sum by (version) (delivery_release_pressure{severity=~"severity::1|severity::2",job="delivery-metrics"})
        |||,
        legendFormat='{{version}}',
        thresholds={
          mode: 'absolute',
          steps: [
            { color: colorScheme.normalRangeColor, value: 0 },
            { color: colorScheme.criticalColor, value: 1 },
          ],
        },
      ),
    ],
    // Column 5: Patch release pressure
    [
      bargaugePanel(
        'Patch release pressure: Total ',
        description='Number of merge requests merged in previous releases regardless severity.',
        query=|||
          sum by (version) (delivery_release_pressure{job="delivery-metrics"})
        |||,
        legendFormat='{{version}}',
        thresholds={
          mode: 'absolute',
          steps: [
            { color: colorScheme.normalRangeColor, value: null },
            { color: colorScheme.warningColor, value: 5 },
            { color: colorScheme.errorColor, value: 10 },
            { color: colorScheme.criticalColor, value: 15 },
          ],
        },
      ),
    ],
    // Column 6: Post deploy migration pressure
    [
      pendingPDMMetricPanel('gprd', mimirHelper.mimirDatasource('gitlab-gprd')),
      pendingPDMMetricPanel('gstg', mimirHelper.mimirDatasource('gitlab-gstg')),
    ],
  ], cellHeights=[singleCellHeight for x in environments], startRow=1)
)
.addPanels(
  std.flattenArrays(
    std.mapWithIndex(
      function(index, environment)
        local y = 2000 * (index + 1);
        [
          row.new(
            title='%s %s' % [environment.icon, environment.id]
          )
          { gridPos: { x: 0, y: y, w: 24, h: 12 } },
        ]
        +
        layout.grid(
          [
            environmentPressurePanel(environment),
          ],
          cols=2,
          startRow=y + 2
        ),
      environments
    )
  )
)
.addPanel(
  panel.basic(
    'Auto-build pressure for auto-deploy projects',
    description='Number of commits not included in an auto-deploy package for projects whose versions are bumped by release-tools',
  )
  .addYaxis(
    min=0,
    label='Commits',
  )
  .addTarget(
    prometheus.target(
      'sum(delivery_auto_build_pressure{project_name=~"%(projects)s"})' % { projects: buildPressureProjects },
      legendFormat='sum',
    )
  ),
  gridPos={ x: 50, y: 2000, w: 12, h: 10 }
)
.addPanel(
  panel.basic(
    'Auto-build pressure for all projects',
    description='Number of commits (in all projects) not included in an auto-deploy package',
  )
  .addYaxis(
    min=0,
    label='Commits',
  )
  .addTarget(
    prometheus.target(
      'max(delivery_auto_build_pressure) by (project_name)',
      legendFormat='{{project_name}}',
    )
  ),
  gridPos={ x: 50, y: 4000, w: 12, h: 10 }
)
.trailer()
