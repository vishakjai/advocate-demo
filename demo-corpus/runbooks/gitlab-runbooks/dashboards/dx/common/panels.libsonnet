// Shared panel helpers for Developer Experience dashboards
// Only contains items used by 2+ dashboards

local config = import './config.libsonnet';

{
  // ============================================================================
  // FACTORY FUNCTIONS
  // ============================================================================

  datasourceUid:: config.datasourceUid,
  clickHouseDatasource:: { type: 'grafana-clickhouse-datasource', uid: $.datasourceUid },

  // ============================================================================
  // RISK LEVEL
  // ============================================================================

  riskLevelMappings:: [
    {
      options: {
        CRITICAL: { color: 'red', index: 0 },
        HIGH: { color: 'orange', index: 1 },
        MEDIUM: { color: 'yellow', index: 2 },
        LOW: { color: 'green', index: 3 },
      },
      type: 'value',
    },
  ],

  riskLevelOverride(columnWidth=90):: {
    matcher: { id: 'byName', options: 'Risk Level' },
    properties: [
      { id: 'custom.width', value: columnWidth },
      { id: 'mappings', value: $.riskLevelMappings },
      { id: 'custom.cellOptions', value: { type: 'color-text' } },
    ],
  },

  // ============================================================================
  // PANEL HELPERS
  // ============================================================================

  timeSeriesPanel(title='', rawSql='', unit='short', showValues=false, description='', displayName='', axisLabel='', legendCalcs=[], legendPlacement='bottom'):: {
    type: 'timeseries',
    title: title,
    datasource: $.clickHouseDatasource,
    description: description,
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisCenteredZero: false,
          axisColorMode: 'text',
          axisLabel: axisLabel,
          axisPlacement: 'auto',
          barAlignment: 0,
          barWidthFactor: 0.6,
          drawStyle: 'line',
          fillOpacity: 0,
          gradientMode: 'none',
          hideFrom: { legend: false, tooltip: false, viz: false },
          insertNulls: false,
          lineInterpolation: 'linear',
          lineWidth: 1,
          pointSize: 5,
          scaleDistribution: { type: 'linear' },
          showPoints: 'auto',
          showValues: showValues,
          spanNulls: false,
          stacking: { group: 'A', mode: 'none' },
          thresholdsStyle: { mode: 'off' },
        },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
        unit: unit,
      } + (if displayName != '' then { displayName: displayName } else {}),
      overrides: [],
    },
    options: {
      legend: { calcs: legendCalcs, displayMode: if std.length(legendCalcs) > 0 then 'table' else 'list', placement: legendPlacement, showLegend: true },
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
    },

    targets: [
      {
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: rawSql,
        refId: 'A',
      },
    ],
  },

  textPanel(text='', title='', content=''):: {
    type: 'text',
    title: if title != '' then title else '',
    options: {
      content: if content != '' then content else text,
    },
  },

  tablePanel(title='', rawSql='', sortBy=[], overrides=[], description='', transformations=[]):: {
    type: 'table',
    title: title,
    datasource: $.clickHouseDatasource,
    description: description,
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        custom: {
          align: 'auto',
          cellOptions: { type: 'auto' },
          footer: { reducers: [] },
          inspect: false,
        },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
      },
      overrides: overrides,
    },
    options: {
      cellHeight: 'sm',
      enablePagination: true,
      showHeader: true,
      sortBy: sortBy,
    },

    targets: [
      {
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: rawSql,
        refId: 'A',
      },
    ],
    transformations: transformations,
  },

  gaugePanel(title='', rawSql='', description=''):: {
    type: 'gauge',
    title: title,
    datasource: $.clickHouseDatasource,
    description: description,
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 5 }] },
        unit: 'percent',
      },
      overrides: [],
    },
    options: {
      orientation: 'auto',
      reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false },
      showThresholdLabels: false,
      showThresholdMarkers: true,
      sizing: 'auto',
    },

    targets: [
      {
        editorType: 'sql',
        format: 1,
        queryType: 'table',
        rawSql: rawSql,
        refId: 'A',
      },
    ],
  },

  piePanel(title, rawSql, description='', transformations=[], overrides=[]):: {
    type: 'piechart',
    title: title,
    datasource: $.clickHouseDatasource,
    description: description,
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          hideFrom: { legend: false, tooltip: false, viz: false },
        },
        decimals: 1,
        mappings: [],
      },
      overrides: overrides,
    },
    options: {
      displayLabels: [],
      legend: { displayMode: 'table', placement: 'right', showLegend: true, values: ['percent', 'value'] },
      pieType: 'pie',
      reduceOptions: { calcs: ['lastNotNull'], fields: '', values: true },
      sort: 'desc',
      tooltip: { hideZeros: false, mode: 'single', sort: 'none' },
    },

    targets: [
      {
        datasource: $.clickHouseDatasource,
        editorType: 'sql',
        format: 1,
        meta: {
          builderOptions: {
            columns: [],
            database: '',
            limit: 1000,
            mode: 'list',
            queryType: 'table',
            table: '',
          },
        },
        pluginVersion: '4.11.2',
        queryType: 'table',
        rawSql: rawSql,
        refId: 'A',
      },
    ],
    transformations: transformations,
  },

  statPanel(title='', field='', rawSql='', description='', overrides=[], graphMode='none', showPercentChange=false):: {
    type: 'stat',
    title: title,
    datasource: $.clickHouseDatasource,
    description: description,
    fieldConfig: {
      defaults: {
        color: { fixedColor: '#95959f', mode: 'fixed' },
        mappings: [],
        thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] },
        unit: 'short',
      },
      overrides: overrides,
    },
    options: {
      colorMode: 'value',
      graphMode: graphMode,
      justifyMode: if graphMode != 'none' then 'auto' else 'center',
      orientation: 'auto',
      percentChangeColorMode: if graphMode != 'none' then 'standard' else 'inverted',
      reduceOptions: { calcs: if graphMode != 'none' then ['lastNotNull'] else ['mean'], fields: if field != '' then field else '', values: false },
      showPercentChange: showPercentChange,
      textMode: 'auto',
      wideLayout: true,
    },

    targets: [
      {
        editorType: 'sql',
        format: if graphMode != 'none' then 0 else 1,
        queryType: if graphMode != 'none' then 'timeseries' else 'table',
        rawSql: if rawSql != '' then rawSql else field,
        refId: 'A',
      },
    ],
  },
}
