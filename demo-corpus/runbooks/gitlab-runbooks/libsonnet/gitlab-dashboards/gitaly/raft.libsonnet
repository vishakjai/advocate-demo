local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  snapshot_duration(selectorHash, legend)::
    panel.timeSeries(
      title='Raft Snapshot P95 Duration',
      description='The 95th percentile duration of snapshot operations performed for Raft state persistence. Snapshots are created periodically to compact the Raft log and restore the state machine in case of recovery. This metric indicates how long it takes to create and save these snapshots, which is a critical operation for long-term system stability. Prolonged snapshot durations may indicate issues with disk I/O or excessive state size.',
      query=|||
        histogram_quantile(0.95, sum(rate(gitaly_raft_snapshot_duration_seconds_bucket{%(selector)s}[$__interval])) by (le, storage))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat=legend,
      interval='1m',
      linewidth=1,
      format='s',
    ),

  proposal_duration(selectorHash, legend)::
    panel.timeSeries(
      title='Raft Proposal 95 Duration',
      description='The 95th percentile of time taken to commit proposals through the Raft consensus algorithm. This latency metric represents the end-to-end time from when a proposal is submitted until it is successfully committed. Higher values indicate slower consensus operations, which can impact overall system performance. Duration increases may indicate network issues, disk I/O bottlenecks, or resource constraints.',
      query=|||
        histogram_quantile(0.95, sum(rate(gitaly_raft_proposal_duration_seconds_bucket{%(selector)s}[$__interval])) by (le, storage))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat=legend,
      interval='1m',
      linewidth=1,
      format='s',
    ),

  proposals_rate(selectorHash, legend)::
    panel.timeSeries(
      title='Raft Proposals Rate',
      description='Rate of Raft proposals broken down by success and error results. Proposals represent write operations submitted to the Raft cluster for consensus. This metric shows the volume of write operations and their success rate, which is critical for understanding write throughput and potential issues with the consensus process.',
      query=|||
        sum(rate(gitaly_raft_proposals_total{%(selector)s}[$__interval])) by (storage, result)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat=legend,
      interval='1m',
      linewidth=1,
    ),

  log_entries_processed(selectorHash, legend)::
    panel.timeSeries(
      title='Raft Log Entries Processed',
      description='Rate of log entries processed by the Raft consensus algorithm. Shows both append (entries being added to the log) and commit (entries being applied to the state machine) operations across different entry types such as configuration changes and normal entries. This metric indicates overall Raft consensus activity and throughput.',
      query=|||
        sum(rate(gitaly_raft_log_entries_processed{%(selector)s}[$__interval])) by (storage, operation, entry_type)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat=legend,
      interval='1m',
      linewidth=1,
    ),

  proposal_queue_depth(selectorHash, legend)::
    panel.timeSeries(
      title='Raft Proposal Queue Depth',
      description='Current depth of the Raft proposal queue. This gauge metric shows how many proposals (write operations) are waiting to be processed by the Raft consensus algorithm. A consistently high queue depth may indicate processing bottlenecks or resource constraints in the Raft subsystem.',
      query=|||
        gitaly_raft_proposal_queue_depth{%(selector)s}
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat=legend,
      interval='1m',
      linewidth=1,
    ),

  event_loop_crashes(selectorHash, legend)::
    panel.timeSeries(
      title='Raft Event Loop Crashes',
      description='Counter of Raft event loop crashes. This metric indicates critical failures in the Raft consensus mechanism event processing loop. Each crash triggers an automatic recovery by Gitaly, but frequent crashes may indicate system instability or resource issues. This is the most severe Raft reliability indicator.',
      query=|||
        gitaly_raft_event_loop_crashes_total{%(selector)s}
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat=legend,
      interval='1m',
      linewidth=1,
    ),
  warning_panel()::
    basic.text(
      title='⚠️ Raft Feature Warning',
      mode='markdown',
      content=|||
        **IMPORTANT:** The Raft feature in Gitaly is currently being rolled out gradually under heavy control and is not available generally.

        For more information, please visit the [**Raft replication proof of concept**](https://gitlab.com/groups/gitlab-org/-/epics/13562) or reach out to the Gitaly team on [Slack](https://gitlab.enterprise.slack.com/archives/C3ER3TQBT).
      |||
    ),
}
