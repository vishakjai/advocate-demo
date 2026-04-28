local resourceSaturationPoint = (import 'servicemetrics/metrics.libsonnet').resourceSaturationPoint;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

local pgbouncer_client_conn(maxClientConns, name, appliesToServiceTypes) =
  local formatConfig = {
    name: name,
    nameLower: std.asciiLower(name),
  };

  resourceSaturationPoint({
    title: 'PGBouncer Client Connections per Process (%(name)s)' % formatConfig,
    severity: 's2',
    horizontallyScalable: true,  // Add more pgbouncer processes
    appliesTo: appliesToServiceTypes,
    description: |||
      Client connections per pgbouncer process for %(name)s connections.

      pgbouncer is configured to use a `max_client_conn` setting. This limits the total number of client connections per pgbouncer.

      When this limit is reached, client connections may be refused, and `max_client_conn` errors may appear in the pgbouncer logs.

      This could affect users as Rails clients are left unable to connect to the database. Another potential knock-on effect
      is that Rails clients could fail their readiness checks for extended periods during a deployment, leading to saturation of
      the older nodes.
    ||| % formatConfig,
    grafana_dashboard_uid: 'sat_pgb_client_conn_%(nameLower)s' % formatConfig,
    resourceLabels: ['fqdn'],
    burnRatePeriod: '5m',
    queryFormatConfig: {
      /** This value is configured in chef - make sure that it's kept in sync */
      maxClientConns: maxClientConns,
    },
    query: |||
      max_over_time(pgbouncer_used_clients{%(selector)s}[%(rangeInterval)s])
      /
      %(maxClientConns)g
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  });

{
  pgbouncer_client_conn_primary_main: pgbouncer_client_conn(maxClientConns=18000, name='Primary_Main', appliesToServiceTypes=['pgbouncer']),
  pgbouncer_client_conn_primary_ci: pgbouncer_client_conn(maxClientConns=18000, name='Primary_CI', appliesToServiceTypes=['pgbouncer-ci']),
  pgbouncer_client_conn_primary_registry: pgbouncer_client_conn(maxClientConns=15000, name='Primary_Reg', appliesToServiceTypes=['pgbouncer-registry']),
  pgbouncer_client_conn_primary_sec: pgbouncer_client_conn(maxClientConns=15000, name='Primary_Sec', appliesToServiceTypes=['pgbouncer-sec']),
  pgbouncer_client_conn_replicas: pgbouncer_client_conn(maxClientConns=30000, name='Replicas', appliesToServiceTypes=['patroni', 'patroni-registry', 'patroni-ci', 'patroni-sec']),
}
