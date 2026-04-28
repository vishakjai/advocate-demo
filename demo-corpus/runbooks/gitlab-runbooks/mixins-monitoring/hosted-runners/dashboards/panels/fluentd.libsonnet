local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local emitRecords(selector) =
  panel.timeSeries(
    title='Current emit records',
    legendFormat='{{shard}} - {{plugin}}',
    format='short',
    query=|||
      sum by (shard, plugin) (
        increase(fluentd_output_status_emit_records{%(selector)s}[5m])
      )
    ||| % { selector: selector }
  );

local retryWait(selector) =
  panel.timeSeries(
    title='Current retry wait',
    legendFormat='{{shard}} - {{plugin}}',
    format='short',
    query=|||
      sum by (shard, plugin) (
        rate(fluentd_output_status_retry_wait{%(selector)s}[5m])
      )
    ||| % { selector: selector }
  );

local writeCounts(selector) =
  panel.timeSeries(
    title='Current write counts',
    legendFormat='{{shard}} - {{plugin}}',
    format='short',
    query=|||
      sum by (shard, plugin) (
        increase(fluentd_output_status_write_count{%(selector)s}[5m])
      )
    ||| % { selector: selector }
  );

local errorAndRetryRate(selector) =
  panel.timeSeries(
    title='Fluentd output error/retry rate',
    legendFormat='{{shard}} - {{plugin}} - Retry rate',
    format='ops',
    query=|||
      sum by (shard, plugin) (
        rate(fluentd_output_status_retry_count{%(selector)s}[5m])
      )
    ||| % { selector: selector }
  ).addTarget(
    target.prometheus(
      expr=|||
        sum by (shard, plugin) (
            rate(fluentd_output_status_num_errors{%(selector)s}[5m])
        )
      ||| % { selector: selector },
      legendFormat='{{shard}} - {{plugin}} - Error rate',
    )
  );

local outputFlushTime(selector) =
  panel.timeSeries(
    title='Fluentd output status flush time rate',
    legendFormat='{{shard}} - {{plugin}} - Time',
    format='ms',
    query=|||
      sum by (shard, plugin) (
        rate(fluentd_output_status_flush_time_count{%(selector)s}[5m])
      )
    ||| % { selector: selector }
  );

local bufferLength(selector) =
  panel.timeSeries(
    title='Maximum buffer length in last 5min',
    legendFormat='{{shard}} - {{plugin}} - Count',
    format='short',
    query=|||
      sum by (shard, plugin) (
        max_over_time(fluentd_output_status_buffer_queue_length{%(selector)s}[5m])
      )
    ||| % { selector: selector }
  );

local bufferTotalSize(selector) =
  panel.timeSeries(
    title='Total size of queue buffers',
    legendFormat='{{shard}} - {{plugin}}',
    format='bytes',
    query=|||
      sum by (shard, plugin) (
        fluentd_output_status_buffer_total_bytes{%(selector)s}
      )
    ||| % { selector: selector }
  );

local bufferFreeSpace(selector) =
  panel.timeSeries(
    title='Buffer available space ratio',
    legendFormat='{{shard}} - {{plugin}}',
    format='percent',
    fill=1,
    query=|||
      min by(plugin, shard) (
        fluentd_output_status_buffer_available_space_ratio{%(selector)s}
      )
    ||| % { selector: selector }
  );

{
  new(selectorHash):: {
    local selector = selectors.serializeHash(selectorHash),

    emitRecords:: emitRecords(selector),
    retryWait:: retryWait(selector),
    writeCounts:: writeCounts(selector),
    errorAndRetryRate:: errorAndRetryRate(selector),
    outputFlushTime:: outputFlushTime(selector),
    bufferLength:: bufferLength(selector),
    bufferTotalSize:: bufferTotalSize(selector),
    bufferFreeSpace:: bufferFreeSpace(selector),
  },
}
