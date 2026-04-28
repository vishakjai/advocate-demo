local alerts = import 'alerts/alerts.libsonnet';

local filesystemExt4ErrorsAlerts() =
  [
    {
      alert: 'FilesystemExt4Errors',
      expr: |||
        increase(filesystem_ext4_errors_total{env="gprd", service="gitaly"}[5m]) > 0
      |||,
      'for': '5m',
      labels: {
        team: 'tenant_services',
        alert_type: 'cause',
        severity: 's3',
      },
      annotations: {
        title: 'EXT4 filesystem errors detected on Gitaly node',
        description: |||
          EXT4 filesystem errors have been detected on Gitaly node {{ $labels.fqdn }}
          at mountpoint {{ $labels.mountpoint }} (device {{ $labels.device }}).

          This indicates potential disk corruption or hardware issues that could lead to
          data loss or service degradation. Immediate investigation is required.

          Current error count: {{ $value }}
        |||,
        runbook: 'gitaly/filesystem-errors/',
      },
    },
  ];

{
  filesystemExt4ErrorsAlerts():
    alerts.processAlertRules(filesystemExt4ErrorsAlerts()),
}
