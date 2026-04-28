local strings = import 'utils/strings.libsonnet';

local defaultDatasourceUid = 'clickhouse-runway-production';
local defaultDatabase = 'observability';
local defaultTable = 'otel_logs';
local defaultServiceField = 'ServiceName';
local dashboardTimeFrom = '${__from}';
local dashboardTimeTo = '${__to}';

// TODO: Move to a lib for this - perhaps https://jsonnet-libs.github.io/xtd/url/
local uriEncodeComponent(str) =
  strings.urlEncode(
    str,
    [
      ['%', '%25'],
      [' ', '%20'],
      ['"', '%22'],
      ['#', '%23'],
      ['&', '%26'],
      ['+', '%2B'],
      [',', '%2C'],
      ['/', '%2F'],
      [':', '%3A'],
      [';', '%3B'],
      ['<', '%3C'],
      ['=', '%3D'],
      ['>', '%3E'],
      ['?', '%3F'],
      ['@', '%40'],
      ['[', '%5B'],
      ['\\', '%5C'],
      [']', '%5D'],
      ['{', '%7B'],
      ['|', '%7C'],
      ['}', '%7D'],
      ["'", '%27'],
      ['(', '%28'],
      [')', '%29'],
      ['$', '%24'],
      ['\n', '%0A'],
    ]
  );

local escapeSqlString(value) =
  std.strReplace(value, "'", "''");

local buildRawSql(database, table, serviceField, serviceName, matches={}) =
  local serviceClause = if serviceName == null then
    []
  else
    ["%s = '%s'" % [serviceField, escapeSqlString(serviceName)]];

  local matchClauses = std.map(
    function(field)
      "%s = '%s'" % [field, escapeSqlString(matches[field])],
    std.objectFields(matches)
  );

  local clauses = serviceClause + matchClauses;
  local whereSuffix = if std.length(clauses) > 0 then
    ' AND ( ' + std.join(' AND ', clauses) + ' )'
  else
    '';

  'SELECT TimestampTime as "timestamp", Body as "body", SeverityText as "level", Attributes as "labels" FROM "%s"."%s" WHERE ( timestamp >= $__fromTime AND timestamp <= $__toTime )%s ORDER BY timestamp DESC LIMIT 1000' % [
    database,
    table,
    whereSuffix,
  ];

local buildBuilderFilters(serviceField, serviceName, matches={}) =
  local timeFilter = {
    type: 'datetime',
    operator: 'WITH IN DASHBOARD TIME RANGE',
    filterType: 'custom',
    key: '',
    hint: 'time',
    condition: 'AND',
  };
  local serviceFilter = if serviceName == null then
    []
  else
    [{
      filterType: 'custom',
      key: serviceField,
      type: 'LowCardinality(String)',
      condition: 'AND',
      operator: '=',
      label: serviceField,
      value: serviceName,
    }];
  local matchFilters = std.map(
    function(field)
      {
        filterType: 'custom',
        key: field,
        type: 'LowCardinality(String)',
        condition: 'AND',
        operator: '=',
        label: field,
        value: matches[field],
      },
    std.objectFields(matches)
  );
  [timeFilter] + serviceFilter + matchFilters;

local buildExplorePanesJson(datasourceUid, database, table, serviceField, serviceName, matches={}, from=dashboardTimeFrom, to=dashboardTimeTo) =
  std.manifestJsonMinified({
    logs: {
      datasource: datasourceUid,
      queries: [{
        refId: 'A',
        datasource: {
          type: 'gitlab-clickhouse-datasource',
          uid: datasourceUid,
        },
        pluginVersion: '4.10.2',
        editorType: 'builder',
        rawSql: buildRawSql(database, table, serviceField, serviceName, matches),
        builderOptions: {
          database: database,
          table: table,
          queryType: 'logs',
          mode: 'list',
          columns: [
            { name: 'TimestampTime', hint: 'time' },
            { name: 'SeverityText', hint: 'log_level' },
            { name: 'Body', hint: 'log_message' },
            { name: 'Attributes', hint: 'log_labels' },
          ],
          limit: 1000,
          filters: buildBuilderFilters(serviceField, serviceName, matches),
          orderBy: [
            {
              name: '',
              hint: 'time',
              dir: 'DESC',
              default: true,
            },
          ],
        },
        format: 2,
      }],
      range: {
        from: from,
        to: to,
      },
      panelsState: {
        logs: {
          sortOrder: 'Descending',
        },
      },
      compact: false,
    },
  });

{
  buildClickhouseExploreLogsURL(
    serviceName=null,
    datasourceUid=defaultDatasourceUid,
    database=defaultDatabase,
    table=defaultTable,
    serviceField=defaultServiceField,
    matches={},
    from=null,
    to=null,
  )::
    local resolvedFrom = if from != null then from else dashboardTimeFrom;
    local resolvedTo = if to != null then to else dashboardTimeTo;
    local encodedPanes = uriEncodeComponent(
      buildExplorePanesJson(datasourceUid, database, table, serviceField, serviceName, matches, resolvedFrom, resolvedTo)
    );
    // Grafana interpolates ${__from}/${__to} in links before navigation.
    // Keep these macros unencoded so pane-local range can receive dashboard time.
    local panesWithMacros = std.strReplace(
      std.strReplace(encodedPanes, '%24%7B__from%7D', '${__from}'),
      '%24%7B__to%7D',
      '${__to}'
    );
    local timeRangeQuery = if from != null && to != null then
      'from=%s&to=%s' % [uriEncodeComponent(from), uriEncodeComponent(to)]
    else
      '${__url_time_range}';
    'https://dashboards.gitlab.net/explore?schemaVersion=1&panes=%s&orgId=1&%s' % [
      panesWithMacros,
      timeRangeQuery,
    ],
}
