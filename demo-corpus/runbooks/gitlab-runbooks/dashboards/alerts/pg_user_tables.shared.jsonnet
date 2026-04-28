local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local template = grafana.template;
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

{
  pg_user_tables_primary:
    basic.dashboard(
      'pg User Table Alerts Primary',
      tags=['alert-target', 'gcp'],
    )
    .addTemplate(template.new(
      'fqdn',
      '$PROMETHEUS_DS',
      'label_values(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment"}, fqdn)',
      refresh='load',
      sort=1,
    ))
    .addTemplate(template.new(
      'relname',
      '$PROMETHEUS_DS',
      'label_values(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment", fqdn="$fqdn"}, relname)',
      refresh='load',
      sort=1,
    ))
    .addPanels(layout.grid(
      [
        panel.timeSeries(
          title='Tuple Fetches per Second',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            )
          |||,
          legendFormat='{{relname}}',
          linewidth=2,
          max=null,
        )
        .addTarget(
          target.prometheus(
            |||
              increase(pg_stat_user_tables_analyze_count{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            |||,
            legendFormat='Analyze {{ relname }}'
          )
        )
        .addTarget(
          target.prometheus(
            |||
              increase(pg_stat_user_tables_vacuum_count{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            |||,
            legendFormat='Vacuum {{ relname }}'
          )
        )
        .addSeriesOverride({
          alias: '/^Analyze .*/',
          yaxis: 2,
          zindex: -3,
        })
        .addSeriesOverride({
          alias: '/^Vacuum .*/',
          yaxis: 2,
          zindex: -3,
        }),
        panel.timeSeries(
          title='Tuple Fetches as Percentage of Total for Host',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            )
            / ignoring (relname) group_left()
            sum by (environment, tier, type, fqdn) (
              rate(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment", fqdn="$fqdn"}[$__rate_interval])
            )
          |||,
          format='percentunit',
          legendFormat='{{relname}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Tuple Modifies per Second',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_n_tup_ins{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            )
          |||,
          legendFormat='insert {{relname}}',
          linewidth=2,
        )
        .addTarget(
          target.prometheus(
            |||
              rate(pg_stat_user_tables_n_tup_upd{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            |||,
            legendFormat='update {{ relname }}'
          )
        )
        .addTarget(
          target.prometheus(
            |||
              rate(pg_stat_user_tables_n_tup_del{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            |||,
            legendFormat='delete {{ relname }}'
          )
        )
        .addTarget(
          target.prometheus(
            |||
              rate(pg_stat_user_tables_n_tup_hot_upd{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            |||,
            legendFormat='hot update {{ relname }}'
          )
        ),
      ],
      cols=1,
      rowHeight=15,
    ))
    .addPanels(layout.grid(
      [
        panel.timeSeries(
          title='Index Scans per Second',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_idx_scan{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            )
          |||,
          legendFormat='{{relname}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Index Tuple Fetches per Second',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
            )
          |||,
          legendFormat='{{relname}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Live Tuples',
          query=|||
            pg_stat_user_tables_n_live_tup{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}
          |||,
          legendFormat='Live tuples: {{relname}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Dead Tuples',
          query=|||
            pg_stat_user_tables_n_dead_tup{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}
          |||,
          legendFormat='Dead tuples: {{relname}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Seq Scans',
          query=|||
            rate(pg_stat_user_tables_seq_scan{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
          |||,
          legendFormat='{{relname}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Rows returned by seq scans',
          query=|||
            rate(pg_stat_user_tables_seq_tup_read{type="patroni", env="$environment", relname="$relname", fqdn="$fqdn"}[$__rate_interval])
          |||,
          legendFormat='{{relname}}',
          linewidth=2,
        ),
      ],
      cols=2,
      rowHeight=8,
      startRow=100,
    ))
    .trailer(),
  pg_user_tables_replica:
    basic.dashboard(
      'pg User Table Alerts Replicas',
      tags=['alert-target', 'gcp'],
    )
    .addTemplate(template.new(
      'relname',
      '$PROMETHEUS_DS',
      'label_values(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment"}, relname)',
      refresh='load',
      sort=1,
    ))
    .addPanels(layout.grid(
      [
        panel.timeSeries(
          title='Tuple Fetches per Second',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
            )
          |||,
          legendFormat='{{fqdn}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Tuple Fetches as Percentage of Total across all Postgres instances',
          query=|||
            sum by (environment, tier, type, relname) (
              rate(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
            )
            / ignoring (relname) group_left()
            sum by (environment, tier, type) (
              rate(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment"}[$__rate_interval])
            )
          |||,
          format='percentunit',
          legendFormat='{{relname}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Tuple Modifies per Second',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_n_tup_ins{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
            )
          |||,
          legendFormat='insert {{fqdn}}',
          linewidth=2,
        )
        .addTarget(
          target.prometheus(
            |||
              rate(pg_stat_user_tables_n_tup_upd{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
            |||,
            legendFormat='update {{ fqdn }}'
          )
        )
        .addTarget(
          target.prometheus(
            |||
              rate(pg_stat_user_tables_n_tup_del{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
            |||,
            legendFormat='delete {{ fqdn }}'
          )
        )
        .addTarget(
          target.prometheus(
            |||
              rate(pg_stat_user_tables_n_tup_hot_upd{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
            |||,
            legendFormat='hot update {{ fqdn }}'
          )
        ),
      ],
      cols=1,
      rowHeight=15,
    ))
    .addPanels(layout.grid(
      [
        panel.timeSeries(
          title='Index Scans per Second',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_idx_scan{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
            )
          |||,
          legendFormat='{{fqdn}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Index Tuple Fetches per Second',
          query=|||
            sum by (environment, tier, type, fqdn, relname) (
              rate(pg_stat_user_tables_idx_tup_fetch{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
            )
          |||,
          legendFormat='{{fqdn}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Live Tuples',
          query=|||
            pg_stat_user_tables_n_live_tup{type="patroni", env="$environment", relname="$relname"}
          |||,
          legendFormat='Live tuples: {{fqdn}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Dead Tuples',
          query=|||
            pg_stat_user_tables_n_dead_tup{type="patroni", env="$environment", relname="$relname"}
          |||,
          legendFormat='Dead tuples: {{fqdn}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Seq Scans',
          query=|||
            rate(pg_stat_user_tables_seq_scan{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
          |||,
          legendFormat='{{fqdn}}',
          linewidth=2,
        ),
        panel.timeSeries(
          title='Rows returned by seq scans',
          query=|||
            rate(pg_stat_user_tables_seq_tup_read{type="patroni", env="$environment", relname="$relname"}[$__rate_interval])
          |||,
          legendFormat='{{fqdn}}',
          linewidth=2,
        ),
      ],
      cols=2,
      rowHeight=8,
      startRow=100,
    ))
    .trailer(),
}
