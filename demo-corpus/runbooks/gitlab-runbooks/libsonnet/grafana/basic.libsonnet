local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local heatmapPanel = grafana.heatmapPanel;
local text = grafana.text;
local seriesOverrides = import 'grafana/series_overrides.libsonnet';
local gaugePanel = grafana.gaugePanel;
local statPanel = grafana.statPanel;
local tablePanel = grafana.tablePanel;
local timepickerlib = import 'github.com/grafana/grafonnet-lib/grafonnet/timepicker.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local commonAnnotations = import 'grafana/common_annotations.libsonnet';
local stableIds = import 'stable-ids/stable-ids.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local applyStableIdsToPanel(panel) =
  local recursivelyApplied = if std.objectHas(panel, 'panels') then
    panel {
      panels: std.map(function(panel) applyStableIdsToPanel(panel), panel.panels),
    }
  else
    panel;

  if std.objectHasAll(recursivelyApplied, 'stableId') then
    recursivelyApplied {
      id: stableIds.hashStableId(recursivelyApplied.stableId),
    }
  else
    recursivelyApplied;

local applyStableIdsToRow(row) =
  row {
    panels: std.map(function(panel) applyStableIdsToPanel(panel), row.panels),
  };

local applyStableIdsToDashboard(dashboard) =
  dashboard {
    rows: std.map(function(row) applyStableIdsToRow(row), dashboard.rows),
    panels: std.map(function(panel) applyStableIdsToPanel(panel), dashboard.panels),
  };

// Lists all panels under a panel
local panelsForPanel(panel) =
  local childPanels = if std.objectHas(panel, 'panels') then
    std.flatMap(function(panel) panelsForPanel(panel), panel.panels)
  else
    [];
  [panel] + childPanels;

// Lists all panels under a row
local panelsForRow(row) =
  std.flatMap(function(panel) panelsForPanel(panel), row.panels);

// Validates that each panel has a unique ID, otherwise Grafana does odd things
local validateUniqueIdsForDashboard(dashboard) =
  local rowPanels = std.flatMap(panelsForRow, dashboard.rows);
  local directPanels = std.flatMap(panelsForPanel, dashboard.panels);
  local allPanels = rowPanels + directPanels;
  local uniquePanelIds = std.foldl(
    function(memo, panel)
      local panelIdStr = '' + panel.id;
      if std.objectHas(memo, panelIdStr) then
        /**
         * If you find yourself here, the reason is that validation of your dashboard failed
         * due to duplicate IDs. The most likely reason for this is because
         * the `stableId` string for two panels hashed to the same value.
         */
        local assertFormatConfig = {
          panelId: panelIdStr,
          otherPanelTitle: memo[panelIdStr],
          panelTitle: panel.title,
        };
        std.assertEqual('', { __assert__: 'Duplicated panel ID `%(panelId)s`. This will lead to layout problems in Grafana. Titles of panels with duplicate titles are `%(otherPanelTitle)s` and `%(panelTitle)s`' % assertFormatConfig })
      else
        memo { [panelIdStr]: panel.title },
    allPanels,
    {}
  );

  // Force jsonnet to walk all panels
  if uniquePanelIds != null then
    dashboard
  else
    dashboard;

local panelOverrides(stableId) =
  {
    addDataLink(datalink):: self + {
      options+: {
        dataLinks+: [datalink],
      },
    },
  }
  +
  (
    if stableId == null then
      {}
    else
      {
        stableId: stableId,
      }
  );

local getDefaultAvailabilityColorScale(invertColors, factor) =
  local tf = if invertColors then function(value) (1 - value) * factor else function(value) value;
  local scale = [
    {
      color: 'red',
      value: tf(0),
    },
    {
      color: 'light-red',
      value: tf(0.95),
    },
    {
      color: 'orange',
      value: tf(0.99),
    },
    {
      color: 'light-orange',
      value: tf(0.995),
    },
    {
      color: 'yellow',
      value: tf(0.9994),
    },
    {
      color: 'light-yellow',
      value: tf(0.9995),
    },
    {
      color: 'green',
      value: tf(0.9998),
    },
  ];

  std.sort(scale, function(i) if i.value == null then 0 else i.value);

/* Validates each tag on a dashboard */
local validateTag(tag) =
  if !std.isString(tag) then error 'dashboard tags must be strings, got %s' % [tag]
  else if tag == '' then error 'dashboard tag cannot be empty'
  else if std.length(tag) > 50 then error 'dashboard tag cannot exceed 50 characters in length: %s' % [tag]
  else tag;

local validateTags(tags) =
  [
    validateTag(tag)
    for tag in tags
  ];

{
  dashboard(
    title,
    tags,
    editable=false,
    time_from='now-6h/m',
    time_to='now/m',
    graphTooltip='shared_crosshair',
    hideControls=false,
    description=null,
    includeStandardEnvironmentAnnotations=true,
    includeEnvironmentTemplate=true,
    includePrometheusDatasourceTemplate=true,
    uid=null,
    defaultDatasource=null,
  )::
    local baseDashboard =
      grafana.dashboard.new(
        title,
        style='light',
        schemaVersion=16,
        tags=validateTags(tags),
        timezone='utc',
        graphTooltip=graphTooltip,
        editable=editable,
        refresh='',
        timepicker=timepickerlib.new(refresh_intervals=['1m', '5m', '10m', '15m', '30m']),
        hideControls=false,
        description=null,
        time_from=time_from,
        time_to=time_to,
      );

    local dashboard =
      (
        if includePrometheusDatasourceTemplate then
          baseDashboard.addTemplate(templates.ds(defaultDatasource))
        else
          baseDashboard
      )
      +
      {
        [if uid != null then 'uid']: uid,
      };

    local dashboardWithAnnotations = if includeStandardEnvironmentAnnotations then
      dashboard
      .addAnnotation(commonAnnotations.deploymentsForEnvironment)
      .addAnnotation(commonAnnotations.deploymentsForEnvironmentCanary)
      .addAnnotation(commonAnnotations.featureFlags)
      .addAnnotation(commonAnnotations.deploymentsForHttpRouter)
    else
      dashboard;

    local dashboardWithEnvTemplate = if includeEnvironmentTemplate then
      dashboardWithAnnotations
      .addTemplate(templates.environment)
    else
      dashboardWithAnnotations;

    dashboardWithEnvTemplate {
      // Conditionally add a single panel to a dashboard
      addPanelIf(condition, panel, gridPos={})::
        if condition then self.addPanel(panel, gridPos) else self,

      // Conditionally add many panels to a dashboard
      addPanelsIf(condition, panels)::
        if condition then self.addPanels(panels) else self,

      // Conditionally add a template to a dashboard
      addTemplateIf(condition, template)::
        if condition then self.addTemplate(template) else self,

      // Conditionally add many templates to a dashboard
      addTemplatesIf(condition, templates)::
        if condition then self.addTemplates(templates) else self,

      // Conditionally add an annotation to a dashboard
      addAnnotationIf(condition, annotation)::
        if condition then self.addAnnotation(annotation) else self,

      trailer()::
        local dashboardWithTrailerPanel = self.addPanel(
          text.new(
            title='Source',
            mode='markdown',
            content=|||
              Made with ❤️ and [Grafonnet](https://github.com/grafana/grafonnet-lib). [Contribute to this dashboard on GitLab.com](https://gitlab.com/gitlab-com/runbooks/blob/master/dashboards)
            |||,
          ),
          gridPos={
            x: 0,
            y: 110000,
            w: 24,
            h: 2,
          }
        );

        local dashboardWithStableIdsApplied = applyStableIdsToDashboard(dashboardWithTrailerPanel);
        validateUniqueIdsForDashboard(dashboardWithStableIdsApplied),
    },

  heatmap(
    title='Heatmap',
    description='',
    query='',
    legendFormat='',
    interval='1m',
    intervalFactor=1,
    legend_show=false,
    yAxis_format='s',
    color_mode='opacity',
    stableId=null,
    dataFormat='timeseries',
    color_cardColor='#b4ff00',
    color_colorScheme='interpolateOranges',
    hideZeroBuckets=true,
    datasource='$PROMETHEUS_DS',
  )::
    heatmapPanel.new(
      title,
      description=description,
      datasource=datasource,
      legend_show=legend_show,
      yAxis_format=yAxis_format,
      color_mode=color_mode,
      color_cardColor=color_cardColor,
      color_colorScheme=color_colorScheme,
      dataFormat=dataFormat,
      hideZeroBuckets=hideZeroBuckets
    )
    .addTarget(promQuery.target(query, format='heatmap', legendFormat=legendFormat, interval=interval, intervalFactor=intervalFactor))
    + panelOverrides(stableId),

  table(
    title='Table',
    description='',
    span=null,
    min_span=null,
    styles=[],
    columns=[],
    query='',
    queries=null,
    instant=true,
    interval='1m',
    intervalFactor=1,
    stableId=null,
    sort=null,
    transformations=[],
  )::
    local wrappedQueries = if queries == null then [query] else queries;
    local panel = tablePanel.new(
      title,
      description=description,
      span=span,
      min_span=min_span,
      datasource='$PROMETHEUS_DS',
      styles=styles,
      columns=columns,
      sort=sort,
    );
    local populatedTablePanel = std.foldl(
      function(table, query)
        table.addTarget(promQuery.target(query, instant=instant, format='table')),
      wrappedQueries,
      panel
    );
    populatedTablePanel + panelOverrides(stableId) + {
      transformations: transformations,
    },

  slaStats(
    title,
    description='Availability',
    query=null,
    legendFormat='',
    displayName=null,
    links=[],
    stableId=null,
    decimals=2,
    invertColors=false,
    unit='percentunit',
    colors=getDefaultAvailabilityColorScale(invertColors, if unit == 'percentunit' then 1 else 100),
    colorMode='background',
    intervalFactor=1,
    datasource='$PROMETHEUS_DS',
  )::
    statPanel.new(
      title,
      description=description,
      datasource=datasource,
      reducerFunction='last',
      allValues=true,
      orientation='auto',
      colorMode=colorMode,
      graphMode='none',
      justifyMode='auto',
      unit=unit,
      min=0,
      max=1,
      decimals=decimals,
      displayName=displayName,
      thresholdsMode='absolute',
    )
    .addLinks(links)
    .addThresholds(colors)
    .addTarget(
      promQuery.target(
        query,
        legendFormat=legendFormat,
        instant=true,
        intervalFactor=intervalFactor,
      )
    )
    + panelOverrides(stableId),

  // This is a useful hack for displaying a label value in a stat panel
  labelStat(
    query,
    title,
    color,
    legendFormat,
    datasource='$PROMETHEUS_DS',
    links=[],
    stableId=null,
  )::
    statPanel.new(
      title,
      allValues=false,
      datasource=datasource,
      reducerFunction='lastNotNull',
      graphMode='none',
      colorMode='background',
      justifyMode='auto',
      thresholdsMode='absolute',
      unit='none',
      displayName='${__series.name}',
      orientation='vertical',
    )
    .addLinks(links)
    .addThreshold({
      value: null,
      color: color,
    })
    .addTarget(
      promQuery.target(
        query,
        legendFormat=legendFormat,
        instant=true
      )
    )
    + panelOverrides(stableId),

  statPanel(
    title,
    panelTitle,
    color,
    query,
    datasource='$PROMETHEUS_DS',
    legendFormat='',
    format='time_series',
    description='',
    unit='',
    decimals=0,
    min=null,
    max=null,
    instant=true,
    interval='1m',
    intervalFactor=1,
    allValues=false,
    reducerFunction='lastNotNull',
    fields='',
    mappings=[],
    colorMode='background',
    graphMode='none',
    justifyMode='auto',
    textMode='auto',
    thresholdsMode='absolute',
    orientation='vertical',
    noValue=null,
    links=[],
    stableId=null,
    transformations=[],
  )::
    local steps =
      if std.type(color) == 'string' then
        [{ color: color, value: null }]
      else
        color;
    statPanel.new(
      panelTitle,
      description=description,
      datasource=datasource,
      allValues=allValues,
      reducerFunction=reducerFunction,
      fields=fields,
      graphMode=graphMode,
      colorMode=colorMode,
      justifyMode=justifyMode,
      textMode=textMode,
      thresholdsMode=thresholdsMode,
      unit=unit,
      decimals=decimals,
      min=min,
      max=max,
      noValue=noValue,
      displayName=title,
      orientation=orientation,
    )
    .addMappings(mappings)
    .addThresholds(steps)
    .addLinks(links)
    .addTarget(
      promQuery.target(
        query,
        legendFormat=legendFormat,
        format=format,
        instant=instant,
        interval=interval,
        intervalFactor=intervalFactor,
      )
    )
    + panelOverrides(stableId) + {
      transformations: transformations,
    },

  gaugePanel(
    title,
    query,
    legendFormat='',
    format='time_series',
    description='',
    color='green',
    unit='percent',
    min=0,
    max=100,
    decimals=null,
    instant=true,
    interval='1m',
    intervalFactor=1,
    reducerFunction='lastNotNull',
    mappings=[],
    thresholdsMode='absolute',
    colorMode='thresholds',
    noValue=null,
    links=[],
    stableId=null,
  )::
    local steps =
      if std.type(color) == 'string' then
        [{ color: color, value: null }]
      else
        color;
    gaugePanel.new(
      title,
      description=description,
      allValues=false,
      reducerFunction=reducerFunction,
      thresholdsMode=thresholdsMode,
      min=min,
      max=max,
      unit=unit,
      decimals=decimals,
      noValue=noValue,
    )
    .addMappings(mappings)
    .addThresholds(steps)
    .addLinks(links)
    .addTarget(
      promQuery.target(
        query,
        legendFormat=legendFormat,
        format=format,
        instant=instant,
        interval=interval,
        intervalFactor=intervalFactor,
      )
    )
    + {
      fieldConfig+: {
        defaults+: {
          color+: {
            mode: colorMode,
          },
        },
      },
    }
    + panelOverrides(stableId),
  text:: text.new,
}
