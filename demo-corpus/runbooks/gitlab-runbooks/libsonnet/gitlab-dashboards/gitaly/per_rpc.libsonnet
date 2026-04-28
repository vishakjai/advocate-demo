local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  request_rate_by_method(selectorHash)::
    panel.timeSeries(
      title='Request rate by grpc_method',
      description='Request rate for the Gitaly server',
      query=|||
        sum by (grpc_method, grpc_service) (rate(grpc_server_handled_total{%(selector)s}[$__rate_interval]))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      interval='1m',
      legendFormat='/{{ grpc_service}}/{{ grpc_method }}'
    ),
  request_rate_by_code(selectorHash)::
    panel.timeSeries(
      title='Response rate by grpc_code',
      description='Response rate for the Gitaly server',
      query=|||
        sum by (grpc_code) (rate(grpc_server_handled_total{%(selector)s}[$__rate_interval]))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      interval='1m',
      legendFormat='{{grpc_cdoe}}',
    ),
  in_progress_requests(selectorHash)::
    panel.timeSeries(
      title='In progress requests',
      query=|||
        sum(gitaly_concurrency_limiting_in_progress{%(selector)s}) by (fqdn, grpc_service, grpc_method)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='/{{ grpc_service}}/{{ grpc_method }}',
      interval='$__interval',
      linewidth=1,
    ),
  in_progress_requests_by_node(selectorHash)::
    panel.timeSeries(
      title='In progress requests',
      query=|||
        sum(gitaly_concurrency_limiting_in_progress{%(selector)s}) by (fqdn)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{ fqdn }}',
      interval='$__interval',
      linewidth=1,
    ),
  queued_requests(selectorHash)::
    panel.timeSeries(
      title='Queued requests',
      query=|||
        sum(gitaly_concurrency_limiting_queued{%(selector)s}) by (fqdn, grpc_service, grpc_method)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='/{{ grpc_service}}/{{ grpc_method }}',
      interval='$__interval',
      linewidth=1,
    ),
  queued_requests_by_node(selectorHash)::
    panel.timeSeries(
      title='Queued requests',
      query=|||
        sum(gitaly_concurrency_limiting_queued{%(selector)s}) by (fqdn)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{ fqdn }}',
      interval='$__interval',
      linewidth=1,
    ),
  dropped_requests(selectorHash)::
    panel.timeSeries(
      title='Dropped requests (RPS)',
      query=|||
        sum(rate(gitaly_requests_dropped_total{%(selector)s}[$__rate_interval])) by (fqdn, grpc_service, grpc_method, reason)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='/{{ grpc_service}}/{{ grpc_method }} ({{ reason }})',
      interval='$__interval',
      linewidth=1,
    ),
  dropped_requests_by_node(selectorHash)::
    panel.timeSeries(
      title='Dropped requests (RPS)',
      query=|||
        sum(rate(gitaly_requests_dropped_total{%(selector)s}[$__rate_interval])) by (fqdn, reason)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{ reason }} - {{ fqdn }}',
      interval='$__interval',
      linewidth=1,
    ),
  queueing_time(selectorHash)::
    panel.timeSeries(
      title='95th queueing time (RPS)',
      query=|||
        histogram_quantile(0.95, sum(rate(gitaly_concurrency_limiting_acquiring_seconds_bucket{%(selector)s}[$__rate_interval])) by (le, fqdn, grpc_service, grpc_method))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='/{{ grpc_service}}/{{ grpc_method }}',
      interval='$__interval',
      linewidth=1,
      format='s',
    ),
  queueing_time_by_node(selectorHash)::
    panel.timeSeries(
      title='95th queueing time (RPS)',
      query=|||
        histogram_quantile(0.95, sum(rate(gitaly_concurrency_limiting_acquiring_seconds_bucket{%(selector)s}[$__rate_interval])) by (le, fqdn))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{ fqdn }}',
      interval='$__interval',
      linewidth=1,
      format='short',
    ),
}
