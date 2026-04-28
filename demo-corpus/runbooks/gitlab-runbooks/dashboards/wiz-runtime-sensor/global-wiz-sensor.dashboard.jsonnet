local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local panel = import 'grafana/time-series/panel.libsonnet';
local templates = import 'grafana/templates.libsonnet';

grafana.dashboard.new(
  'Enhanced Global Wiz Sensor Dashboard',
  tags=['infrasec', 'managed', 'wiz', 'wiz-runtime-sensor', 'global-monitoring'],
  description='Global Wiz Sensor Infrastructure Monitoring - Multi-Environment Overview',
  refresh='5m',
)
.addTemplate(
  grafana.template.datasource(
    'datasource',
    'prometheus',
    'Data Source',
  )
)
.addPanels([
  // Global Coverage Overview Row
  row.new(title='Global Wiz Sensor Coverage Overview') + { gridPos: { h: 1, w: 24, x: 0, y: 0 } },

  // First 4 stat panels
  {
    type: 'stat',
    title: 'Total Infrastructure Nodes',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'count(node_boot_time_seconds{environment=~"gprd|gstg|pre|ops", namespace=""}) + count(kube_node_info)', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 5, w: 3, x: 0, y: 1 },
  },

  {
    type: 'stat',
    title: 'Total Nodes with Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'count(count by(fqdn) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0)) + sum(kube_daemonset_status_current_number_scheduled{namespace="wiz-sensor", daemonset="wiz-sensor"})', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 5, w: 3, x: 3, y: 1 },
  },

  {
    type: 'stat',
    title: 'Nodes Missing Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'count(node_boot_time_seconds{namespace=""}) - count((namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0))', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 1 }, { color: 'green', value: 10 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 5, w: 3, x: 6, y: 1 },
  },

  {
    type: 'stat',
    title: 'Global Coverage %',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: '(count(namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0)) / count(node_boot_time_seconds{namespace=""}) * 100', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'percentage', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 85 }, { color: 'green', value: 95 }] }, unit: 'percent' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 5, w: 3, x: 9, y: 1 },
  },
  // Nodes without Wiz Sensor Table (Top Right)
  {
    type: 'table',
    title: 'Nodes without Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', exemplar: false, expr: 'group by (fqdn) (node_boot_time_seconds{namespace=""}) unless (group by (fqdn) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0))', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { custom: { align: 'auto', cellOptions: { type: 'auto' }, filterable: true, inspect: true }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { cellHeight: 'sm', enablePagination: false, showHeader: true },
    transformations: [
      { id: 'reduce', options: { labelsToFields: true, reducers: ['max'] } },
      { id: 'reduce', options: { includeTimeField: false, mode: 'reduceFields', reducers: [] } },
      { id: 'groupBy', options: { fields: { fqdn: { aggregations: [], operation: 'groupby' } } } },
    ],
    gridPos: { h: 8, w: 12, x: 12, y: 1 },
  },

  // Global Coverage Gauge (Left Side)
  {
    type: 'gauge',
    title: 'Wiz Global Coverage',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', exemplar: false, expr: '(\n  count by (environment) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0) \n  or \n  (count by (environment) (node_boot_time_seconds{namespace=""}) * 0)\n)\n/ \ncount by (environment) (node_boot_time_seconds{namespace=""}) \n* 100', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { thresholds: { mode: 'percentage', steps: [{ value: 0, color: 'red' }, { value: 85, color: 'yellow' }, { value: 95, color: 'green' }] }, unit: 'percent' } },
    options: { minVizHeight: 75, minVizWidth: 75, orientation: 'auto', reduceOptions: { values: false, calcs: ['lastNotNull'], fields: '' }, showThresholdLabels: false, showThresholdMarkers: false, sizing: 'auto' },
    gridPos: { h: 12, w: 12, x: 0, y: 6 },
  },

  // Environment Coverage Summary Table (Right Side)
  {
    type: 'table',
    title: 'Environment Coverage Summary',
    datasource: '${datasource}',
    targets: [
      { editorMode: 'code', exemplar: false, expr: '(count by (environment) (node_boot_time_seconds{namespace=""}) or (count by (environment) (kube_node_info) * 0))\n+\n(count by (environment) (kube_node_info) or (count by (environment) (node_boot_time_seconds{namespace=""}) * 0))', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'A' },
      { editorMode: 'code', exemplar: false, expr: 'count by(environment) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0) + sum by (environment)(kube_daemonset_status_current_number_scheduled{namespace="wiz-sensor", daemonset="wiz-sensor"})', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'B' },
      { editorMode: 'code', exemplar: false, expr: '(\n  count by (environment) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0) \n  or \n  (count by (environment) (node_boot_time_seconds{namespace=""}) * 0)\n)\n/ \ncount by (environment) (node_boot_time_seconds{namespace=""}) \n* 100', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'C' },
    ],
    fieldConfig: {
      defaults: { custom: { align: 'auto', cellOptions: { type: 'auto' }, filterable: true, inspect: true }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } },
      overrides: [
        { matcher: { id: 'byName', options: 'Environment' }, properties: [{ id: 'custom.width', value: 120 }] },
        { matcher: { id: 'byName', options: 'Total Nodes' }, properties: [{ id: 'custom.width', value: 145 }] },
        { matcher: { id: 'byName', options: 'With Sensor' }, properties: [{ id: 'custom.width', value: 160 }] },
        { matcher: { id: 'byName', options: 'Coverage %' }, properties: [{ id: 'unit', value: 'percent' }, { id: 'thresholds', value: { mode: 'percentage', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 85 }, { color: 'green', value: 95 }] } }] },
      ],
    },
    options: { cellHeight: 'sm', enablePagination: false, showHeader: true },
    transformations: [
      { id: 'merge', options: {} },
      { id: 'organize', options: { excludeByName: { Time: true }, indexByName: { 'Value #A': 1, 'Value #B': 2, 'Value #C': 3, environment: 0 }, renameByName: { 'Value #A': 'Total Nodes', 'Value #B': 'With Sensor', 'Value #C': 'Coverage %', environment: 'Environment' } } },
    ],
    gridPos: { h: 9, w: 12, x: 12, y: 9 },
  },
  // VM Statistics Row
  row.new(title='Infrastructure Statistics - All Environments (VMs)') + { gridPos: { h: 1, w: 24, x: 0, y: 18 } },

  // VM Stats - Second Row (4 stat panels)
  {
    type: 'stat',
    title: 'Total Infrastructure Nodes',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'count(node_boot_time_seconds{namespace=""})', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 4, w: 3, x: 0, y: 19 },
  },

  {
    type: 'stat',
    title: 'Total Nodes with Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'count(count by(fqdn) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0))', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 4, w: 3, x: 3, y: 19 },
  },

  {
    type: 'stat',
    title: 'Nodes Missing Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'count(node_boot_time_seconds{namespace=""}) - count(count by(fqdn) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0))', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 1 }, { color: 'green', value: 10 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 4, w: 3, x: 6, y: 19 },
  },

  {
    type: 'stat',
    title: 'Global Coverage %',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: '(count(count by(fqdn) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0)) / count(node_boot_time_seconds{namespace=""})) * 100', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'percentage', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 85 }, { color: 'green', value: 95 }] }, unit: 'percent' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 4, w: 3, x: 9, y: 19 },
  },

  // Service Wise Availability Table
  {
    type: 'table',
    title: 'Service Wise Wiz Sensor Availability',
    datasource: '${datasource}',
    targets: [
      { editorMode: 'code', exemplar: false, expr: 'count by (service) (node_boot_time_seconds{namespace="", service!=""})', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'A' },
      { editorMode: 'code', exemplar: false, expr: 'count by (service) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"} > 0)', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'B' },
      { editorMode: 'code', exemplar: false, expr: '(count by (service) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"} > 0) / count by (service) (node_boot_time_seconds{namespace="", service!=""})) * 100', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'C' },
    ],
    fieldConfig: {
      defaults: { custom: { align: 'auto', cellOptions: { type: 'auto' }, filterable: true, inspect: true }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } },
      overrides: [
        { matcher: { id: 'byName', options: 'type' }, properties: [{ id: 'custom.width', value: 150 }] },
        { matcher: { id: 'byName', options: 'Total Instances' }, properties: [{ id: 'custom.width', value: 120 }] },
        { matcher: { id: 'byName', options: 'Active Instances' }, properties: [{ id: 'custom.width', value: 120 }] },
        { matcher: { id: 'byName', options: 'Availability %' }, properties: [{ id: 'unit', value: 'percent' }, { id: 'thresholds', value: { mode: 'percentage', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 90 }, { color: 'green', value: 95 }] } }] },
      ],
    },
    options: { cellHeight: 'sm', enablePagination: false, showHeader: true },
    transformations: [
      { id: 'merge', options: {} },
      { id: 'organize', options: { excludeByName: { Time: true }, indexByName: { 'Value #A': 1, 'Value #B': 2, 'Value #C': 3, service: 0 }, renameByName: { 'Value #A': 'Total Instances', 'Value #B': 'Active Instances', 'Value #C': 'Availability %', service: 'Service' } } },
    ],
    gridPos: { h: 12, w: 12, x: 12, y: 19 },
  },

  // Nodes without Wiz Sensor Table (Bottom Left)
  {
    type: 'table',
    title: 'Nodes without Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', exemplar: false, expr: 'group by (fqdn) (node_boot_time_seconds{namespace=""}) unless (group by (fqdn) (namedprocess_namegroup_num_threads{groupname="wiz-sensor"}>0))', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { custom: { align: 'auto', cellOptions: { type: 'auto' }, filterable: true, inspect: true }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { cellHeight: 'sm', enablePagination: false, showHeader: true },
    transformations: [
      { id: 'reduce', options: { labelsToFields: true, reducers: ['max'] } },
      { id: 'reduce', options: { includeTimeField: false, mode: 'reduceFields', reducers: [] } },
      { id: 'groupBy', options: { fields: { fqdn: { aggregations: [], operation: 'groupby' } } } },
    ],
    gridPos: { h: 8, w: 12, x: 0, y: 23 },
  },
  // Time Series Charts for VMs
  {
    type: 'timeseries',
    title: 'Top CPU User Usage',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'topk(5,rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",mode="user"}[1h]))', format: 'time_series', intervalFactor: 1, legendFormat: '{{fqdn}}', range: true, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 0, y: 31 },
  },

  {
    type: 'timeseries',
    title: 'Top CPU System Usage',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'topk(5,rate(namedprocess_namegroup_cpu_seconds_total{groupname="wiz-sensor",mode="system"}[1h]))', format: 'time_series', intervalFactor: 1, legendFormat: '{{fqdn}}', range: true, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 8, y: 31 },
  },

  {
    type: 'timeseries',
    title: 'Average Memory Usage',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'avg (\n  namedprocess_namegroup_memory_bytes{groupname="wiz-sensor"}\n) / 1048576', format: 'time_series', intervalFactor: 1, legendFormat: 'memory per node', range: true, refId: 'B' }],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 16, y: 31 },
  },

  {
    type: 'timeseries',
    title: 'wiz-sensor fleet IO',
    datasource: '${datasource}',
    targets: [
      { editorMode: 'code', expr: 'sum by(fqdn) (rate(namedprocess_namegroup_write_bytes_total{groupname="wiz-sensor"}[5m]))/ 1024', format: 'time_series', intervalFactor: 1, legendFormat: '{{fqdn}}-write', range: true, refId: 'A' },
      { editorMode: 'code', expr: 'sum by(fqdn) (rate(namedprocess_namegroup_read_bytes_total{groupname="wiz-sensor"}[5m]))/ 1024', format: 'time_series', intervalFactor: 1, legendFormat: '{{fqdn}}-read', range: true, refId: 'B' },
    ],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 0, y: 40 },
  },

  {
    type: 'timeseries',
    title: 'Top memory usage',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'topk(5,namedprocess_namegroup_memory_bytes{groupname="wiz-sensor",memtype="resident"} / 1048576)', format: 'time_series', intervalFactor: 1, legendFormat: '{{fqdn}}', range: true, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 8, y: 40 },
  },

  {
    type: 'timeseries',
    title: 'Wiz Sensor Context Switch',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'sum by(fqdn) (rate(namedprocess_namegroup_context_switches_total{groupname="wiz-sensor"}[5m])) / 1000', format: 'time_series', intervalFactor: 1, legendFormat: '__auto', range: true, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 16, y: 40 },
  },
  // K8s Statistics Row
  row.new(title='Infrastructure Statistics - All Environments (K8s)') + { gridPos: { h: 1, w: 24, x: 0, y: 49 } },

  // K8s Stats - Third Row (4 stat panels)
  {
    type: 'stat',
    title: 'Total Infrastructure Nodes',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'count(kube_node_info)', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 4, w: 3, x: 0, y: 50 },
  },

  {
    type: 'stat',
    title: 'Total Nodes with Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'sum(kube_daemonset_status_current_number_scheduled{namespace="wiz-sensor", daemonset="wiz-sensor"})', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 4, w: 3, x: 3, y: 50 },
  },

  {
    type: 'stat',
    title: 'Nodes Missing Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'count(kube_node_info) - sum(kube_daemonset_status_current_number_scheduled{namespace="wiz-sensor", daemonset="wiz-sensor"})', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 1 }, { color: 'green', value: 10 }] }, unit: 'short' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 4, w: 3, x: 6, y: 50 },
  },

  {
    type: 'stat',
    title: 'Global Coverage %',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'sum(kube_daemonset_status_current_number_scheduled{namespace="wiz-sensor", daemonset="wiz-sensor"}) / count(kube_node_info) * 100', instant: true, legendFormat: '__auto', range: false, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'percentage', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 85 }, { color: 'green', value: 95 }] }, unit: 'percent' } },
    options: { colorMode: 'value', graphMode: 'area', justifyMode: 'center', orientation: 'auto', reduceOptions: { calcs: ['lastNotNull'], fields: '', values: false }, textMode: 'auto', wideLayout: true },
    gridPos: { h: 4, w: 3, x: 9, y: 50 },
  },

  // Cluster Wise Availability Table
  {
    type: 'table',
    title: 'Cluster Wise Wiz Sensor Availability',
    datasource: '${datasource}',
    targets: [
      { editorMode: 'code', exemplar: false, expr: 'count by (cluster) (kube_node_info)', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'A' },
      { editorMode: 'code', exemplar: false, expr: 'sum by (cluster) (kube_daemonset_status_current_number_scheduled{namespace="wiz-sensor", daemonset="wiz-sensor"})', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'B' },
      { editorMode: 'code', exemplar: false, expr: '(sum by (cluster) (kube_daemonset_status_current_number_scheduled{namespace="wiz-sensor", daemonset="wiz-sensor"}) / count by (cluster) (kube_node_info)) * 100', format: 'table', instant: true, legendFormat: '__auto', range: false, refId: 'C' },
    ],
    fieldConfig: {
      defaults: { custom: { align: 'auto', cellOptions: { type: 'auto' }, filterable: true, inspect: true }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } },
      overrides: [
        { matcher: { id: 'byName', options: 'type' }, properties: [{ id: 'custom.width', value: 150 }] },
        { matcher: { id: 'byName', options: 'Total Instances' }, properties: [{ id: 'custom.width', value: 120 }] },
        { matcher: { id: 'byName', options: 'Active Instances' }, properties: [{ id: 'custom.width', value: 120 }] },
        { matcher: { id: 'byName', options: 'Availability %' }, properties: [{ id: 'unit', value: 'percent' }, { id: 'thresholds', value: { mode: 'percentage', steps: [{ color: 'red', value: 0 }, { color: 'yellow', value: 90 }, { color: 'green', value: 95 }] } }] },
      ],
    },
    options: { cellHeight: 'sm', enablePagination: false, showHeader: true },
    transformations: [
      { id: 'merge', options: {} },
      { id: 'organize', options: { excludeByName: { Time: true }, indexByName: { 'Value #A': 1, 'Value #B': 2, 'Value #C': 3, cluster: 0 }, renameByName: { 'Value #A': 'Total Instances', 'Value #B': 'Active Instances', 'Value #C': 'Availability %', cluster: 'Cluster' } } },
    ],
    gridPos: { h: 12, w: 12, x: 12, y: 50 },
  },

  // K8s Nodes without Wiz Sensor Table
  {
    type: 'table',
    title: 'Nodes without Wiz Sensor',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'group by (node) (\n  kube_node_info \n  and \n  kube_node_created < (time() - 300)\n)\nunless\ngroup by (node) (\n  kube_pod_status_phase{\n    namespace="wiz-sensor", \n    pod=~"wiz-sensor.*", \n    phase="Running"\n  }\n)', legendFormat: '__auto', range: true, refId: 'A' }],
    fieldConfig: { defaults: { custom: { align: 'auto', cellOptions: { type: 'auto' }, inspect: false }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { cellHeight: 'sm', showHeader: true },
    gridPos: { h: 8, w: 12, x: 0, y: 54 },
  },
  // K8s Time Series Charts
  {
    type: 'timeseries',
    title: 'Top CPU User Usage',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: "sum by (cluster, pod) (topk(2,rate(container_cpu_usage_seconds_total{container='wiz-sensor'}[4m0s])))", format: 'time_series', intervalFactor: 1, legendFormat: '{cluster="{{cluster}}", pod={{pod}}}', range: true, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 0, y: 62 },
  },

  {
    type: 'timeseries',
    title: 'Top Memory Usage',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: 'sum by (cluster,pod) (topk(5,container_memory_usage_bytes{namespace="wiz-sensor",container="wiz-sensor"}))/1048576', format: 'time_series', intervalFactor: 1, legendFormat: '{cluster="{{cluster}}", pod={{pod}}}', range: true, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 8, y: 62 },
  },

  {
    type: 'timeseries',
    title: 'OOM Kills',
    datasource: '${datasource}',
    targets: [{ editorMode: 'code', expr: "topk(5,(container_oom_events_total{container='wiz-sensor'}))", format: 'time_series', intervalFactor: 1, legendFormat: '{cluster="{{cluster}}", pod={{pod}}}', range: true, refId: 'A' }],
    fieldConfig: { defaults: { color: { mode: 'palette-classic' }, custom: { axisBorderShow: false, axisCenteredZero: false, axisColorMode: 'text', axisLabel: '', axisPlacement: 'auto', barAlignment: 0, barWidthFactor: 0.6, drawStyle: 'line', fillOpacity: 0, gradientMode: 'none', hideFrom: { legend: false, tooltip: false, viz: false }, insertNulls: false, lineInterpolation: 'linear', lineWidth: 1, pointSize: 5, scaleDistribution: { type: 'linear' }, showPoints: 'auto', spanNulls: false, stacking: { group: 'A', mode: 'none' }, thresholdsStyle: { mode: 'off' } }, thresholds: { mode: 'absolute', steps: [{ color: 'green', value: 0 }, { color: 'red', value: 80 }] } } },
    options: { legend: { calcs: [], displayMode: 'list', placement: 'bottom', showLegend: true }, tooltip: { hideZeros: false, mode: 'single', sort: 'none' } },
    gridPos: { h: 9, w: 8, x: 16, y: 62 },
  },

])
