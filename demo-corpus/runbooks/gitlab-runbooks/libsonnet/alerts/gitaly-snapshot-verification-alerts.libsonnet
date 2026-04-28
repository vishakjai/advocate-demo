local alerts = import 'alerts/alerts.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local verificationDelayThreshold = 86400;  // 1 day

local gitalySnapshotVerificationAlerts() =
  [
    {
      alert: 'GitalySnapshotVerificationDelayed',
      expr: |||
        time() - max(gitaly_snapshot_verification_finish_timestamp_seconds{}) by (env) > %(delayThreshold)s
      ||| % {
        delayThreshold: verificationDelayThreshold,
      },
      'for': '1h',
      labels: {
        team: 'tenant_services',
        alert_type: 'cause',
        severity: 's4',
      },
      annotations: {
        title: 'Gitaly snapshot verification is delayed',
        description: |||
          Gitaly snapshot verification has not completed in the last day
          for the `{{ $labels.env }}` environment.

          This could indicate issues with the snapshot verification process or
          that snapshots are not being properly verified, which may impact
          disaster recovery capabilities.
        |||,
        runbook: 'gitaly/snapshot-verification/',
      },
    },

    {
      alert: 'GitalySnapshotVerificationNoRecentChanges',
      expr: |||
        gitaly_snapshot_verification_recent_repos_total{} == 0
      |||,
      'for': '1h',
      labels: {
        team: 'tenant_services',
        alert_type: 'cause',
        severity: 's4',
      },
      annotations: {
        title: 'Gitaly snapshot verification found no recent changes',
        description: |||
          Gitaly snapshot verification didn't find any repository with a
          change committed in the last day for the restored instance
          `{{ $labels.gcp_project }}`/`{{ $labels.instance_name }}`.

          This could indicate a problem with the snapshotting process or
          the snapshot used was not restored properly.
        |||,
        runbook: 'gitaly/snapshot-verification/',
      },
    },
  ];

{
  gitalySnaphotVerificationAlerts():
    alerts.processAlertRules(gitalySnapshotVerificationAlerts()),
}
