local basic = import 'grafana/basic.libsonnet';

local successRatioByServiceQuery = |||
  SELECT
    visitParamExtractString(custom_event_props, 'value') as service,
    round(countIf(JSONExtractString(custom_event_props, 'extras', 'exit_code') = '0') / count(), 3) as success_ratio
  FROM default.events
  WHERE custom_event_name = 'Custom service_finish'
  AND derived_tstamp >= '2025-09-10 00:00:00' // Using data from Sept 10 when we fixed crash looping services flooding telemetry with duplicate events
  GROUP BY service
  ORDER BY success_ratio ASC, service ASC
|||;

local recentFailuresQuery = |||
  SELECT
    derived_tstamp,
    visitParamExtractString(custom_event_props, 'value') as service,
    JSONExtractString(custom_event_props, 'extras', 'exit_code') as exit_code,
    JSONExtractString(custom_event_props, 'extras', 'last_error') as last_error
  FROM default.events
  WHERE custom_event_name = 'Custom service_finish'
  AND JSONExtractString(custom_event_props, 'extras', 'exit_code') != '0'
  AND derived_tstamp >= '2025-09-10 00:00:00' // Using data from Sept 10 when we fixed crash looping services flooding telemetry with duplicate events
  ORDER BY derived_tstamp DESC
  LIMIT 50
|||;

local successRatioByServiceTablePanel = {
  fieldConfig: {
    defaults: {
      custom: {
        align: 'auto',
        cellOptions: { type: 'auto' },
        inspect: false,
      },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          { color: 'red', value: null },
          { color: 'yellow', value: 0.7 },
          { color: 'green', value: 0.8001 },
        ],
      },
      color: {
        mode: 'thresholds',
      },
    },
    overrides: [
      {
        matcher: {
          id: 'byName',
          options: 'success_ratio',
        },
        properties: [
          {
            id: 'custom.cellOptions',
            value: {
              type: 'color-background',
              mode: 'gradient',
            },
          },
          {
            id: 'thresholds',
            value: {
              mode: 'absolute',
              steps: [
                { color: 'red', value: null },
                { color: 'yellow', value: 0.7 },
                { color: 'green', value: 0.8001 },
              ],
            },
          },
          {
            id: 'unit',
            value: 'percentunit',
          },
          {
            id: 'custom.align',
            value: 'center',
          },
        ],
      },
      {
        matcher: {
          id: 'byName',
          options: 'service',
        },
        properties: [
          {
            id: 'custom.align',
            value: 'left',
          },
        ],
      },
    ],
  },
  gridPos: { h: 12, w: 24, x: 0, y: 0 },
  options: {
    cellHeight: 'sm',
    footer: {
      countRows: false,
      fields: '',
      reducer: ['sum'],
      show: false,
    },
    showHeader: true,
  },
  targets: [{
    datasource: 'GitLab Development Kit ClickHouse',
    editorType: 'sql',
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
    queryType: 'table',
    rawSql: successRatioByServiceQuery,
    refId: 'A',
  }],
  title: 'Success Ratio by Service',
  type: 'table',
};

local recentFailuresTablePanel = {
  fieldConfig: {
    defaults: {
      custom: {
        align: 'auto',
        cellOptions: { type: 'auto' },
        inspect: false,
      },
      mappings: [],
      thresholds: {
        mode: 'absolute',
        steps: [
          {
            color: 'text',
            value: null,
          },
        ],
      },
    },
    overrides: [],
  },
  gridPos: { h: 12, w: 24, x: 0, y: 12 },
  options: {
    cellHeight: 'sm',
    footer: {
      countRows: false,
      fields: '',
      reducer: ['sum'],
      show: false,
    },
    showHeader: true,
  },
  targets: [{
    datasource: 'GitLab Development Kit ClickHouse',
    editorType: 'sql',
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
    queryType: 'table',
    rawSql: recentFailuresQuery,
    refId: 'A',
  }],
  title: 'Recent Failures (Last 50)',
  type: 'table',
};

local dashboard = basic.dashboard(
  'GDK Service Health',
  tags=['gdk'],
  includeEnvironmentTemplate=false,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource='GitLab Development Kit ClickHouse'
).addPanels([
  successRatioByServiceTablePanel,
  recentFailuresTablePanel,
]) + {
  time: {
    from: 'now-14d',
    to: 'now',
  },
  refresh: '5m',
};

(dashboard {
   templating: { list: [] },
 }).trailer()
