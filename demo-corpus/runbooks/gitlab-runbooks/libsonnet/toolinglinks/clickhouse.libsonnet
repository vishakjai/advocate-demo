local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'clickhouse', type:: 'log' });
local clickhouseLinkBuilder = import 'clickhouselinkbuilder/clickhouse_links.libsonnet';

{
  clickhouse(
    title,
    serviceName=null,
    datasourceUid='clickhouse-runway-production',
    database='observability',
    table='otel_logs',
    serviceField='ServiceName',
    matches={},
  )::
    function(_options)
      [
        toolingLinkDefinition({
          title: '📖 ClickHouse: ' + title + ' logs',
          url: clickhouseLinkBuilder.buildClickhouseExploreLogsURL(
            serviceName=serviceName,
            datasourceUid=datasourceUid,
            database=database,
            table=table,
            serviceField=serviceField,
            matches=matches,
          ),
        }),
      ],

  savedQuery(title, url)::
    function(_options)
      [
        toolingLinkDefinition({
          title: '📖 ClickHouse: ' + title,
          url: url,
        }),
      ],
}
