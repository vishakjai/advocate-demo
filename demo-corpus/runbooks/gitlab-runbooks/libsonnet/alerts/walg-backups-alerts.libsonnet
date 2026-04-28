local alerts = import 'alerts/alerts.libsonnet';
local selectors = import 'promql/selectors.libsonnet';


function(tenant, selector)
  {
    local envSelector = selectors.serializeHash(selector),
    groups: [
      {
        name: 'gitlab-walg-backup.rules',
        rules: [
          {
            record: 'gitlab_com:last_walg_backup_age_in_seconds',
            expr: |||
              min(time() - walg_backup_last_completed_time_seconds{%(selector)s, type=~"patroni.*"}) by (env,environment,type)
            ||| % { selector: envSelector },
          },
          {
            record: 'gitlab_com:last_walg_basebackup_age_in_hours',
            expr: |||
              min without (fqdn,instance) (
                time() -
                (
                  label_replace(gitlab_job_start_timestamp_seconds{resource="walg-basebackup", %(selector)s, exported_type=~".*patroni.*"}, "type", "$1", "exported_type", "(.*)") > 0
                )
              ) / 3600
            ||| % { selector: envSelector },
          },
          {
            record: 'gitlab_com:last_walg_successful_basebackup_age_in_hours',
            expr: |||
              min without (fqdn,instance) (
                time() -
                (
                  label_replace(gitlab_job_success_timestamp_seconds{resource="walg-basebackup", %(selector)s, exported_type=~".*patroni.*"}, "type", "$1", "exported_type", "(.*)") > 0
                )
              ) / 3600
            ||| % { selector: envSelector },
          },
          {
            record: 'gitlab_com:last_walg_failed_basebackup_age_in_hours',
            expr: |||
              min(time() - label_replace(push_time_seconds{exported_job="walg-basebackup", %(selector)s, exported_type=~".*patroni.*"}, "type", "$1", "exported_type", "(.*)")) by (environment,type) / 3600
            ||| % { selector: envSelector },
          },

          // walgBackupDelayed
          alerts.processAlertRule({
            alert: 'walgBackupDelayed',
            expr: 'gitlab_com:last_walg_backup_age_in_seconds{type!="patroni-embedding",  %(selector)s} >= 60 * 15' % { selector: envSelector },
            'for': '5m',
            labels: {
              severity: 's3',
              alert_type: 'symptom',
              team: 'database_operations',
            },
            annotations: {
              title: 'Last WAL was archived "{{ .Value | humanizeDuration }}" ago for env "{{ $labels.environment }}."',
              description: 'WAL-G wal-push archiving WALs to GCS might be not working. Please follow the runbook to review the problem.',
              runbook: 'patroni/postgresql-backups-wale-walg/',
              grafana_min_zoom_hours: '4',
              grafana_variables: 'environment',
              grafana_datasource_id: tenant,
            },
          }),

          // walgBaseBackupDelayed
          alerts.processAlertRule({
            alert: 'walgBaseBackupDelayed',
            expr: 'gitlab_com:last_walg_successful_basebackup_age_in_hours{ %(selector)s, exported_type!~".*14.*|gprd-patroni-security"} >= 30' % { selector: envSelector },
            'for': '5m',
            labels: {
              severity: 's3',
              alert_type: 'symptom',
              team: 'database_operations',
            },
            annotations: {
              title: 'Last successful WAL-G basebackup was seen "{{ $value }}" hours ago for env "{{ $labels.environment }}".',
              description: 'WAL-G backup-push creating full backups and archiving them to GCS might be not working. Please follow the runbook to review the problem.',
              runbook: 'patroni/alerts/walgBaseBackup/',
              grafana_min_zoom_hours: '4',
              grafana_variables: 'environment',
              grafana_datasource_id: tenant,
            },
          }),

          // WALGBaseBackupFailed
          alerts.processAlertRule({
            alert: 'WALGBaseBackupFailed',
            expr: 'gitlab_job_failed{resource="walg-basebackup", type!~".+logical.+", %(selector)s} == 1' % { selector: envSelector },
            'for': '5m',
            labels: {
              severity: 's3',
              alert_type: 'cause',
              team: 'database_operations',
            },
            annotations: {
              title: 'GitLab Job has failed',
              description: 'The GitLab job "{{ $labels.job }}" resource "{{ $labels.resource }}" has failed.',
              runbook: 'patroni/alerts/walgBaseBackup/',
              grafana_min_zoom_hours: '4',
              grafana_variables: 'environment',
              grafana_datasource_id: tenant,
            },
          }),
        ],
      },
    ],
  }
