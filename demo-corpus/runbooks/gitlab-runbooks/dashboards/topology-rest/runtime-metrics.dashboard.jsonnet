local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local type = 'topology-rest';
local formatConfig = {
  selector: selectors.serializeHash({ env: '$environment', environment: '$environment', type: type, job: 'topology-service' }),
};

basic.dashboard(
  'Runtime & Resource Metrics',
  tags=['type:%s' % type, 'detail'],
  includeEnvironmentTemplate=true,
  includeStandardEnvironmentAnnotations=false,
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        stableId='cpu-usage-rate',
        title='CPU Usage Rate by Region',
        query=|||
          sum by (region) (
            rate(process_cpu_seconds_total{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='short',
        yAxisLabel='CPU Cores',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='memory-usage-rss',
        title='Memory Usage (RSS) by Instance',
        query=|||
          process_resident_memory_bytes{%(selector)s}
        ||| % formatConfig,
        legendFormat='{{instance}} - {{region}}',
        format='bytes',
        yAxisLabel='Memory',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='goroutine-count',
        title='Goroutine Count by Instance',
        query=|||
          go_goroutines{%(selector)s}
        ||| % formatConfig,
        legendFormat='{{instance}} - {{region}}',
        format='short',
        yAxisLabel='Goroutines',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='gc-frequency',
        title='GC Frequency',
        query=|||
          sum by (region) (
            rate(go_gc_duration_seconds_count{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='ops',
        yAxisLabel='GC per Second',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='gc-pause-time-p99',
        title='GC Pause Time P99',
        query=|||
          histogram_quantile(0.99,
            sum by (le, region) (
              rate(go_gc_duration_seconds_bucket{%(selector)s}[$__rate_interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='s',
        yAxisLabel='Pause Duration',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='file-descriptor-usage',
        title='File Descriptor Usage %',
        query=|||
          (
            process_open_fds{%(selector)s}
            /
            process_max_fds{%(selector)s}
          ) * 100
        ||| % formatConfig,
        legendFormat='{{instance}} - {{region}}',
        format='percent',
        yAxisLabel='FD Usage',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='heap-memory-inuse',
        title='Heap Memory In Use',
        query=|||
          go_memstats_heap_inuse_bytes{%(selector)s}
        ||| % formatConfig,
        legendFormat='{{instance}} - {{region}}',
        format='bytes',
        yAxisLabel='Heap Memory',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='heap-memory-utilization',
        title='Heap Memory Utilization %',
        query=|||
          (
            go_memstats_heap_inuse_bytes{%(selector)s}
            /
            go_memstats_heap_sys_bytes{%(selector)s}
          ) * 100
        ||| % formatConfig,
        legendFormat='{{instance}} - {{region}}',
        format='percent',
        yAxisLabel='Heap Utilization',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='virtual-memory-usage',
        title='Virtual Memory Usage',
        query=|||
          process_virtual_memory_bytes{%(selector)s}
        ||| % formatConfig,
        legendFormat='{{instance}} - {{region}}',
        format='bytes',
        yAxisLabel='Virtual Memory',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='process-uptime',
        title='Process Uptime',
        query=|||
          time() - process_start_time_seconds{%(selector)s}
        ||| % formatConfig,
        legendFormat='{{instance}} - {{region}}',
        format='s',
        yAxisLabel='Uptime',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='heap-objects',
        title='Heap Objects Count',
        query=|||
          go_memstats_heap_objects{%(selector)s}
        ||| % formatConfig,
        legendFormat='{{instance}} - {{region}}',
        format='short',
        yAxisLabel='Object Count',
        interval='1m',
      ),
      panel.timeSeries(
        stableId='gc-overhead',
        title='GC Time Overhead',
        query=|||
          sum by (region) (
            rate(go_gc_duration_seconds_sum{%(selector)s}[$__rate_interval])
          )
        ||| % formatConfig,
        legendFormat='{{region}}',
        format='s',
        yAxisLabel='Time in GC per Second',
        interval='1m',
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=0,
  )
)
.trailer()
