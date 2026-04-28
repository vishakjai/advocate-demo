local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local row = grafana.row;
local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local threshold = import 'grafana/time-series/threshold.libsonnet';

serviceDashboard.overview('consul', startRow=1)
.addPanels(
  layout.grid([
    basic.statPanel(
      title='',
      panelTitle='Consul Leader Node',
      color='blue',
      query='consul_raft_state_leader{environment="$environment"} == 1',
      legendFormat='{{ pod }}',
      colorMode='value',
      textMode='name',
    ),
    basic.statPanel(
      title='',
      panelTitle='Consul Raft Failure Tolerance',
      query='min(consul_autopilot_failure_tolerance{environment="$environment"})',
      legendFormat='',
      colorMode='value',
      textMode='value',
      unit='short',
      color=[
        { color: 'red', value: 0 },
        { color: 'orange', value: 1 },
        { color: 'green', value: 2 },
      ],
    ),
    basic.statPanel(
      title='',
      panelTitle='Consul Raft Autopilot Status',
      query='min(consul_autopilot_healthy{environment="$environment"})',
      legendFormat='',
      colorMode='value',
      textMode='value',
      mappings=[
        {
          id: 0,
          type: 1,
          value: '0',
          text: 'Not Healthy',
        },
        {
          id: 1,
          type: 1,
          value: '1',
          text: 'Healthy',
        },
      ],
      color=[
        { color: 'red', value: 0 },
        { color: 'green', value: 1 },
      ],
    ),
    basic.statPanel(
      title='',
      panelTitle='Consul CA Certificate Expiration',
      query='min(x509_cert_not_after{environment="$environment",secret_namespace="consul",secret_name=~"consul-tls-v.+"}) - time()',
      legendFormat='',
      colorMode='value',
      textMode='value',
      unit='dtdurations',
      color=[
        { color: 'red' },  // expiring in less than 2 weeks
        { color: 'orange', value: 3600 * 24 * 14 },  // in expiring 2 to 4 weeks
        { color: 'green', value: 3600 * 24 * 28 },  // expiring in more than 4 weeks
      ],
    ),
  ], cols=4, rowHeight=5, startRow=0),
)
.addPanel(
  row.new(title='Consul Integrated Storage (Raft)', collapse=true)
  .addPanels(
    layout.grid(
      [
        panel.timeSeries(
          title='Raft Transactions',
          description=|||
            Raft transaction rate.
          |||,
          query='rate(consul_raft_apply{environment="$environment"}[$__interval])',
          legendFormat='{{ pod }}',
          format='ops'
        ),
        panel.timeSeries(
          title='Raft Commit Time',
          description=|||
            Time to commit a new entry to the Raft log on the leader.
          |||,
          query='consul_raft_commitTime{environment="$environment"}',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms'
        ),
      ],
      cols=2,
      rowHeight=10,
      startRow=0,
    ),
  )
  .addPanels(
    layout.grid(
      [
        panel.timeSeries(
          title='Raft Replication Append Entries Rate',
          description=|||
            Number of logs replicated to a node, to bring it up to speed with the leader's logs.
          |||,
          query='rate(consul_raft_replication_appendEntries_logs{environment="$environment"}[$__interval])',
          legendFormat='{{ pod }}',
          format='short'
        ),
        panel.timeSeries(
          title='Raft Replication Append Entries',
          description=|||
            Time taken by the append entries RPC, to replicate the log entries of a leader node onto its follower node(s).
          |||,
          query='consul_raft_replication_appendEntries_rpc{environment="$environment"}',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms'
        ),
        panel.timeSeries(
          title='Raft Replication Heartbeat',
          description=|||
            Time taken by the append entries RPC, to replicate the log entries of a leader node onto its follower node(s).
          |||,
          query='consul_raft_replication_heartbeat{environment="$environment"}',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms'
        ),
      ],
      cols=3,
      rowHeight=10,
      startRow=3,
    ),
  )
  .addPanels(
    layout.grid(
      [
        panel.timeSeries(
          title='Raft RPC Append Entries',
          description=|||
            Time taken to process an append entries RPC call from a node.
          |||,
          query='consul_raft_rpc_appendEntries{environment="$environment"}',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms'
        ),
        panel.timeSeries(
          title='Raft RPC Append Entries: Process Logs',
          description=|||
            Time taken to process the outstanding log entries of a node.
          |||,
          query='consul_raft_rpc_appendEntries_processLogs{environment="$environment"}',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms'
        ),
        panel.timeSeries(
          title='Raft RPC Append Entries: Store Logs',
          description=|||
            Time taken to add any outstanding logs for a node, since the last appendEntries was invoked.
          |||,
          query='consul_raft_rpc_appendEntries_storeLogs{environment="$environment"}',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms'
        ),
        panel.timeSeries(
          title='Raft RPC Process Heartbeat',
          description=|||
            Time taken to process a heartbeat request.
          |||,
          query='consul_raft_rpc_processHeartbeat{environment="$environment"}',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms'
        ),
      ],
      cols=4,
      rowHeight=10,
      startRow=4,
    ),
  ),
  gridPos={ x: 0, y: 200, w: 24, h: 1 },
)
.addPanel(
  row.new(title='Consul Integrated Storage (Raft) Leadership Changes', collapse=true)
  .addPanels(
    layout.grid(
      [
        panel.timeSeries(
          title='Raft Leader Last Contact',
          description=|||
            Time since the leader was last able to contact the follower nodes when checking its leader lease.
          |||,
          query='consul_raft_leader_lastContact{environment="$environment"}',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms',
          thresholdSteps=[
            threshold.warningLevel(200),
          ],
        ),
        panel.timeSeries(
          title='Raft State Changes',
          description=|||
            Candidate/follower/leader state changes.
          |||,
          query='increase(consul_raft_state_candidate{environment="$environment"}[$__interval])',
          legendFormat='{{ pod }}: candidate',
          format='short'
        )
        .addTarget(
          target.prometheus(
            'increase(consul_raft_state_follower{environment="$environment"}[$__interval])',
            legendFormat='{{ pod }}: follower',
          )
        )
        .addTarget(
          target.prometheus(
            'increase(consul_raft_state_leader{environment="$environment"}[$__interval])',
            legendFormat='{{ pod }}: leader',
          )
        ),
      ],
      cols=2,
      rowHeight=10,
      startRow=0,
    ),
  ),
  gridPos={ x: 0, y: 200, w: 24, h: 1 }
)
.addPanel(
  row.new(title='Consul KV and Transaction Latency', collapse=true)
  .addPanels(
    layout.grid(
      [
        panel.timeSeries(
          title='KV Update Latency',
          description=|||
            KV Update time rate.
          |||,
          query='rate(consul_kvs_apply_sum{environment="$environment"}[$__interval])',
          legendFormat='{{ pod }}',
          format='ops'
        ),
        panel.timeSeries(
          title='Transaction time anomalies',
          description=|||
            Consul Transaction time.
          |||,
          query='rate(consul_txn_apply_sum{environment="$environment"}[$__interval])',
          legendFormat='{{ pod }} (p{{ quantile }})',
          format='ms'
        ),
      ],
      cols=2,
      rowHeight=10,
      startRow=0,
    ),
  ),
  gridPos={ x: 0, y: 200, w: 24, h: 1 }
)
.addPanel(
  row.new(title='Garbage Collection', collapse=true)
  .addPanels(
    layout.grid(
      [
        panel.timeSeries(
          title='Garbage Collection Pause',
          description=|||
            Consul’s garbage collector has the pause event that blocks all runtime
            threads until the garbage collection completes.
            This process takes just a few nanoseconds, but if Consul’s memory usage is high,
            that could trigger more and more GC events that could potentially slow down Consul.
          |||,
          query='rate(consul_runtime_gc_pause_ns_sum"}[$__interval])',
          legendFormat='{{ pod }}',
          format='ns'
        ),
      ],
      cols=1,
      rowHeight=10,
      startRow=0,
    ),
  ),
  gridPos={ x: 0, y: 200, w: 24, h: 1 }
)
.overviewTrailer()
