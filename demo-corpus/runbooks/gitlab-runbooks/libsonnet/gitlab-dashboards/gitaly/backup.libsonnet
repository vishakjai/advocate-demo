local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  backup_duration(selectorHash)::
    panel.timeSeries(
      title='Backup duration by phase',
      query=|||
        histogram_quantile(0.99,
          sum(rate(gitaly_backup_latency_seconds_bucket[5m])) by (fqdn, le, phase)
        )
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{phase}}',
      linewidth=1,
      format='s',
    ),
  backup_rpc_status(selectorHash)::
    panel.timeSeries(
      title='BackupRepository RPC status',
      query=|||
        sum(rate(grpc_server_handled_total{grpc_method="BackupRepository"}[1m])) by (fqdn, grpc_code)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{grpc_code}}',
      linewidth=1,
    ),
  backup_rpc_latency(selectorHash)::
    panel.timeSeries(
      title='BackupRepository RPC latency',
      query=|||
        histogram_quantile(0.99, sum by(fqdn, le) (rate(grpc_server_handling_seconds_bucket{grpc_method="BackupRepository"}[5m])))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{le}}',
      linewidth=1,
      format='s',
    ),
  backup_bundle_upload_rate(selectorHash)::
    panel.timeSeries(
      title='Backup bundle upload rate',
      query=|||
        sum by(fqdn) (rate(gitaly_backup_bundle_bytes_sum[$__rate_interval]))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      linewidth=1,
      format='Bps',
    ),
}
