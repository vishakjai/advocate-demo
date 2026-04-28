local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  // The current limit of pack-objects adaptive limit. This metric is visible
  // only if the adaptive is enabled. It shares the same metrics with per-RPC
  // limiting and can be differentiated by limit="packObjects" label.
  // References:
  // - https://gitlab.com/gitlab-org/gitaly/blob/bcc104f73a97e05ab45e2136fa68af33a5b93304/internal/limiter/adaptive_calculator.go#L102
  // - https://gitlab.com/gitlab-org/gitaly/blob/bcc104f73a97e05ab45e2136fa68af33a5b93304/internal/cli/gitaly/serve.go#L317-L329
  pack_objects_current_limit(selectorHash, legend)::
    panel.timeSeries(
      title='Gitaly current pack-objects adaptive limit (visible if adaptiveness is enabled)',
      query=|||
        max(gitaly_concurrency_limiting_current_limit{%(selector)s}) by (fqdn, limit)
      ||| % { selector: selectors.serializeHash(selectorHash { limit: 'packObjects' }) },
      legendFormat=legend + '- Per IP',
      interval='$__interval',
      linewidth=1,
    ),
  // The current limit of per-RPC adaptive limit. This metric is similar to the
  // above metric, execept it has limit label starting with "perRPC". For
  // example, limit="perRPC/gitaly.SmartHTTPService/PostUploadPackWithSidechannel".
  // References:
  // - https://gitlab.com/gitlab-org/gitaly/blob/bcc104f73a97e05ab45e2136fa68af33a5b93304/internal/grpc/middleware/limithandler/middleware.go#L169
  per_rpc_current_limit(selectorHash, legend)::
    panel.timeSeries(
      title='Gitaly current per-RPC adaptive limit (visible if adaptiveness is enabled)',
      query=|||
        max(gitaly_concurrency_limiting_current_limit{%(selector)s}) by (fqdn, limit)
      ||| % { selector: selectors.serializeHash(selectorHash { limit: { re: 'perRPC.*' } }) },
      legendFormat=legend,
      interval='$__interval',
      linewidth=1,
    ),
  watcher_errors(selectorHash, legend)::
    panel.timeSeries(
      title='Adaptive limiting watcher errors (fail to get status from resource watchers)',
      query=|||
        sum(rate(gitaly_concurrency_limiting_watcher_errors_total{%(selector)s}[$__rate_interval])) by (fqdn, watcher)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat=legend,
      interval='$__interval',
      linewidth=1,
    ),
  backoff_events(selectorHash, legend)::
    panel.timeSeries(
      title='Adaptive limiting backoff events (events that cutoff current limits)',
      query=|||
        sum(rate(gitaly_concurrency_limiting_backoff_events_total{%(selector)s}[$__rate_interval])) by (fqdn, watcher)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat=legend,
      interval='$__interval',
      linewidth=1,
    ),
}
