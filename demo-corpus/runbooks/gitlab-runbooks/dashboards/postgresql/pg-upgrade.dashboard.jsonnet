local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local row = grafana.row;

local panels = import 'gitlab-dashboards/panels.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local clusterNameTemplate = grafana.template.new(
  'cluster',
  '$PROMETHEUS_DS',
  'label_values(pg_settings_server_version_num, fqdn)',
  regex='/patroni-(\\w+)-/',
  current='main',
);

// source version relies on the minimum server version for the cluster
local sourceVersionTemplate = grafana.template.new(
  'source_version',
  '$PROMETHEUS_DS',
  'query_result(min by(__name__) (pg_settings_server_version_num{fqdn=~"patroni-main.*"}))',
  regex='/.*\\} (\\d{2})/',
  refresh='load',
  sort=1,
);

// destination version relies on naming convention of v(version_number) in fqdn
local destinationVersionTemplate = grafana.template.new(
  'destination_version',
  '$PROMETHEUS_DS',
  'label_values(pg_settings_server_version_num{fqdn=~"patroni-${cluster}.*"}, fqdn)',
  regex='/.*v(\\d{2})/',
  refresh='load',
  sort=1,
);

local logicalReplicationLag =
  panel.basic(
    title='Logical replication lag (all slots in $environment)',
    legend_min=false,
    legend_current=false,
    unit='bytes',
    fill=100,
  )
  .addTarget(
    target.prometheus(
      |||
        sum(pg_replication_slots_confirmed_flush_lsn_bytes{env="$environment", slot_type="logical"}) by (fqdn, slot_type, slot_name)
      |||,
    ),
  );

local context =
  panels.generalTextPanel(
    'Context',
    content='# **$environment** **$cluster** **source_version**',
    transparent=true
  );

local usefulLinks =
  panels.generalTextPanel('Useful links',
                          content='\n- [Ansible playbooks](https://gitlab.com/gitlab-com/gl-infra/db-migration/-/tree/master/pg-upgrade-logical)\n- [Inventory in Ansible](https://gitlab.com/gitlab-com/gl-infra/db-migration/-/tree/master/pg-upgrade-logical/inventory)\n- [CR template](https://gitlab.com/gitlab-com/gl-infra/db-migration/-/blob/master/.gitlab/issue_templates/pg14_upgrade.md) (individual CRs are to be located at ops.gitlab.net)\n- [Diagram illustrating the process](https://gitlab.com/gitlab-com/gl-infra/db-migration/-/blob/master/.gitlab/issue_templates/pg14_upgrade.md#high-level-overview)\n    ',
                          transparent=true);

local clusterLeft =
  panels.generalTextPanel('Cluster on the left', content='🏹 Source cluster: PG${source_version}, Ubuntu 20.04', transparent=true);
local clusterRight =
  panels.generalTextPanel('Cluster on the right', content='🎯 Target cluster: PG${destination_version} ', transparent=true);

local replicationLagSourceSeconds =
  panel.basic(
    '🏹 🏃🏻‍♀️ Physical replication lag on source standbys, in seconds',
    legend_min=false,
    legend_current=false,
    unit='seconds',
  )
  .addTarget(
    target.prometheus(
      |||
        sum(pg_replication_lag{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}) by (fqdn)
      |||,
    ),
  );

local replicationLagTargetSeconds =
  panel.basic(
    '🎯 🏃🏻‍♀️ Physical replication lag on target standbys, in seconds',
    legend_min=false,
    legend_current=false,
    unit='seconds',
  )
  .addTarget(
    target.prometheus(
      |||
        sum(pg_replication_lag{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}) by (fqdn)
      |||,
    ),
  );

local replicationLagSourceBytes =
  panel.basic(
    '🏹 🏃🏻‍♀️ Physical replication lag on source standbys, in bytes',
    legend_min=false,
    legend_current=false,
    unit='bytes',
  )
  .addTarget(
    target.prometheus(
      |||
        sum(postgres:pg_replication_lag_bytes{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}) by (fqdn)
      |||,
    ),
  );

local replicationLagTargetBytes =
  panel.basic(
    '🎯 🏃🏻‍♀️ Physical replication lag on target standbys, in bytes',
    legend_min=false,
    legend_current=false,
    unit='bytes',
  )
  .addTarget(
    target.prometheus(
      |||
        sum(postgres:pg_replication_lag_bytes{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}) by (fqdn)
      |||,
    ),
  );

local sourceLeaderTPSCommits =
  panel.basic(
    '🏹 🥇 Source leader TPS (commits) ✅',
    legend_min=false,
    legend_current=false,
    unit='ops/sec',
    fill=100,
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(irate(pg_stat_database_xact_commit{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==0
      |||,
    ),
  );

local targetLeaderTPSCommits =
  panel.basic(
    '🎯 🥇 Target leader TPS (commits) ✅',
    legend_min=false,
    legend_current=false,
    unit='ops/sec',
    fill=100,
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(irate(pg_stat_database_xact_commit{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==0
      |||,
    ),
  );

local sourceStandbysTPSCommits =
  panel.basic(
    '🏹 👥 Source standbys TPS (commits) ✅',
    legend_min=false,
    legend_current=false,
    unit='ops/sec'
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(irate(pg_stat_database_xact_commit{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==1
      |||,
    ),
  );

local targetStandbysTPSCommits =
  panel.basic(
    '🎯 👥 Target standbys TPS (commits) ✅',
    legend_min=false,
    legend_current=false,
    unit='ops/sec',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(irate(pg_stat_database_xact_commit{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==1
      |||,
    ),
  );

local sourceLeaderRollbackTPSErrors =
  panel.basic(
    '🏹 🥇 Source leader rollback TPS – ERRORS ❌',
    legend_min=false,
    legend_current=false,
    unit='err/s',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(irate(pg_stat_database_xact_rollback{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==0
      |||,
    ),
  );

local targetLeaderRollbackTPSErrors =
  panel.basic(
    '🎯 🥇 Target leader rollback TPS – ERRORS ❌',
    legend_min=false,
    legend_current=false,
    unit='err/s',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(irate(pg_stat_database_xact_rollback{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==0
      |||,
    ),
  );

local sourceStandbysRollbackTPSErrors =
  panel.basic(
    '🏹 👥 Source standbys roolback TPS – ERRORS ❌',
    legend_min=false,
    legend_current=false,
    unit='err/s',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(irate(pg_stat_database_xact_rollback{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==1
      |||,
    ),
  );

local targetStandbysRollbackTPSErrors =
  panel.basic(
    '🎯 👥 Target standbys rollback TPS – ERRORS ❌',
    legend_min=false,
    legend_current=false,
    unit='err/s',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(irate(pg_stat_database_xact_rollback{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==1
      |||,
    ),
  );

local sourceWritesTuple =
  panel.basic(
    '🏹 Source writes (tuple ins/upd/del)',
    legend_min=false,
    legend_current=false,
    unit='ops/s',
  )
  .addTarget(
    target.prometheus(
      |||
        sum(irate(pg_stat_user_tables_n_tup_ins{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])
        +
        irate(pg_stat_user_tables_n_tup_del{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])
        +
        irate(pg_stat_user_tables_n_tup_upd{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])) by (instance)
        and on(instance) pg_replication_is_replica==0
      |||,
    ),
  );

local targetWritesTuple =
  panel.basic(
    '🎯 Target writes (tuple ins/upd/del)',
    legend_min=false,
    legend_current=false,
    unit='ops/s',
  )
  .addTarget(
    target.prometheus(
      |||
        sum(irate(pg_stat_user_tables_n_tup_ins{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])
        +
        irate(pg_stat_user_tables_n_tup_del{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])
        +
        irate(pg_stat_user_tables_n_tup_upd{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])) by (instance)
        and on(instance) pg_replication_is_replica==0
      |||,
    ),
  );

local sourceIndexTupleFetches =
  panel.basic(
    '🏹 Source index tuple fetches',
    legend_min=false,
    legend_current=false,
    unit='ops/s',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(rate(pg_stat_user_tables_idx_tup_fetch{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==1
      |||,
    ),
  );

local targetIndexTupleFetches =
  panel.basic(
    '🎯 Target index tuple fetches',
    legend_min=false,
    legend_current=false,
    unit='ops/s',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(rate(pg_stat_user_tables_idx_tup_fetch{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==1
      |||,
    ),
  );

local sourceSeqTupleReads =
  panel.basic(
    '🏹 Source seq tuple reads',
    legend_min=false,
    legend_current=false,
    unit='ops/s',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(rate(pg_stat_user_tables_seq_tup_read{env="$environment", fqdn=~"(patroni-${cluster}-v${source_version}|patroni-${cluster}-[0-9]+).*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==1
      |||,
    ),
  );

local targetSeqTupleReads =
  panel.basic(
    '🎯 Target seq tuple reads',
    legend_min=false,
    legend_current=false,
    unit='ops/s',
  )
  .addTarget(
    target.prometheus(
      |||
        (sum(rate(pg_stat_user_tables_seq_tup_read{env="$environment", fqdn=~"patroni-${cluster}-v${destination_version}-.*"}[1m])) by (instance)) and on(instance) pg_replication_is_replica==1
      |||,
    ),
  );

basic.dashboard(
  'Postgres upgrade using logical',
  tags=['postgresql'],
)

.addTemplate(clusterNameTemplate)
.addTemplate(sourceVersionTemplate)
.addTemplate(destinationVersionTemplate)
.addPanel(context, gridPos={ x: 0, y: 0, w: 6, h: 7 })
.addPanel(clusterLeft, gridPos={ x: 0, y: 7, w: 6, h: 3 })
.addPanel(logicalReplicationLag, gridPos={ x: 6, y: 0, w: 12, h: 10 })
.addPanel(usefulLinks, gridPos={ x: 18, y: 0, w: 6, h: 7 })
.addPanel(clusterRight, gridPos={ x: 18, y: 7, w: 6, h: 3 })
.addPanel(
  row.new(title='Physical lags', collapse=true)
  .addPanel(replicationLagSourceSeconds, gridPos={ x: 0, y: 11, w: 12, h: 10 })
  .addPanel(replicationLagTargetSeconds, gridPos={ x: 12, y: 11, w: 12, h: 10 })
  .addPanel(replicationLagSourceBytes, gridPos={ x: 0, y: 21, w: 12, h: 10 })
  .addPanel(replicationLagTargetBytes, gridPos={ x: 12, y: 21, w: 12, h: 10 }),
  gridPos={
    x: 0,
    y: 11,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='TPS (commits)', collapse=true)
  .addPanel(sourceLeaderTPSCommits, gridPos={ x: 0, y: 12, w: 12, h: 8 })
  .addPanel(targetLeaderTPSCommits, gridPos={ x: 12, y: 12, w: 12, h: 8 })
  .addPanel(sourceStandbysTPSCommits, gridPos={ x: 0, y: 20, w: 12, h: 8 })
  .addPanel(targetStandbysTPSCommits, gridPos={ x: 12, y: 20, w: 12, h: 8 }),
  gridPos={
    x: 0,
    y: 12,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='TPS rollbacks – ERROR RATES', collapse=true)
  .addPanel(sourceLeaderRollbackTPSErrors, gridPos={ x: 0, y: 13, w: 12, h: 8 })
  .addPanel(targetLeaderRollbackTPSErrors, gridPos={ x: 12, y: 13, w: 12, h: 8 })
  .addPanel(sourceStandbysRollbackTPSErrors, gridPos={ x: 0, y: 21, w: 12, h: 8 })
  .addPanel(targetStandbysRollbackTPSErrors, gridPos={ x: 12, y: 21, w: 12, h: 8 }),
  gridPos={
    x: 0,
    y: 13,
    w: 24,
    h: 1,
  }
)
.addPanel(
  row.new(title='Tuple stats: ins/upd/del, index fetches, seq reads', collapse=true)
  .addPanel(sourceWritesTuple, gridPos={ x: 0, y: 14, w: 12, h: 8 })
  .addPanel(targetWritesTuple, gridPos={ x: 12, y: 14, w: 12, h: 8 })
  .addPanel(sourceIndexTupleFetches, gridPos={ x: 0, y: 22, w: 12, h: 8 })
  .addPanel(targetIndexTupleFetches, gridPos={ x: 12, y: 22, w: 12, h: 8 })
  .addPanel(sourceSeqTupleReads, gridPos={ x: 0, y: 30, w: 12, h: 8 })
  .addPanel(targetSeqTupleReads, gridPos={ x: 12, y: 30, w: 12, h: 8 }),
  gridPos={
    x: 0,
    y: 14,
    w: 24,
    h: 1,
  }
)
