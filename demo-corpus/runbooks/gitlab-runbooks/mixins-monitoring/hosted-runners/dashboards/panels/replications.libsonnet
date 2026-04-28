local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local barPanel(title, legendFormat, format, query) =
  panel.timeSeries(
    title=title,
    legendFormat=legendFormat,
    format=format,
    query=query,
    fill=1,
    drawStyle='bars',
  );

local pendingOperations(selector) =
  barPanel(
    title='Operations pending replication',
    legendFormat='Pending operations',
    format='short',
    query=|||
      avg_over_time(aws_s3_operations_pending_replication_sum{%(selector)s}[10m])
    ||| % { selector: selector }
  );

local latency(selector) =
  panel.timeSeries(
    title='Replication latency',
    legendFormat='Latency',
    format='ms',
    query=|||
      avg_over_time(aws_s3_replication_latency_maximum{%(selector)s}[10m])
    ||| % { selector: selector }
  );


local bytesPending(selector) =
  barPanel(
    title='Bytes pending replication',
    legendFormat='Bytes pending',
    format='bytes',
    query=|||
      avg_over_time(aws_s3_bytes_pending_replication_maximum{%(selector)s}[10m])
    ||| % { selector: selector }
  );

local operationsFailed(selector) =
  panel.timeSeries(
    title='Operations failed replication',
    legendFormat='Failed replication',
    format='short',
    query=|||
      avg_over_time(aws_s3_operations_failed_replication_sum{%(selector)s}[10m])
    ||| % { selector: selector }
  );

{
  new(selectorHash):: {
    local selector = selectors.serializeHash(selectorHash),

    pendingOperations:: pendingOperations,
    latency:: latency,
    bytesPending:: bytesPending,
    operationsFailed:: operationsFailed,
  },
}
