local periodicQuery = import './periodic-query.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local defaultSelector = {
  env: 'gprd',
  environment: 'gprd',
};

local bloatSelector = {
  job: 'scrapeConfig/monitoring/prometheus-agent-postgres-database-bloat',

};

{
  database_table_size_daily: periodicQuery.new({
    requestParams: {
      query: |||
        max by (relname, type, fqdn) (pg_total_relation_size_bytes{%(selectors)s})
      ||| % {
        selectors: selectors.serializeHash(defaultSelector),
      },
    },
  }),
}

{
  database_table_bloat_ratio_daily: periodicQuery.new({
    requestParams: {
      query: |||
        max by (type, query_name) (last_over_time(gitlab_database_bloat_table_bloat_ratio{%(selectors)s}[1h]))
      ||| % {
        selectors: selectors.serializeHash(defaultSelector + bloatSelector),
      },
    },
  }),
}
