local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

{
  logMessages(startRow)::
    layout.grid(
      [
        panel.timeSeries(
          title='Log messages with severity ERROR',
          query='sum(stackdriver_gke_container_logging_googleapis_com_log_entry_count{severity="ERROR", pod_id=~"^$Deployment.*", cluster_name="$cluster", namespace_id="$namespace"}) / 60',
          legendFormat='ERROR msgs per second',
        ),
        panel.timeSeries(
          title='Log messages with severity INFO',
          query='sum(stackdriver_gke_container_logging_googleapis_com_log_entry_count{severity="INFO", pod_id=~"^$Deployment.*", cluster_name="$cluster", namespace_id="$namespace"}) / 60',
          legendFormat='INFO msgs per second',
        ),
      ],
      cols=2,
      rowHeight=5,
      startRow=startRow,
    ),

  generalCounters(startRow)::
    layout.grid(
      [
        panel.timeSeries(
          title='Process CPU Time',
          query='rate(process_cpu_seconds_total{service=~"^$Deployment.*", cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"}[$__interval])',
          legendFormat='{{ pod }}',
          format='percentunit',
        ),
        panel.timeSeries(
          title='Resident Memory Usage',
          query='process_resident_memory_bytes{service=~"^$Deployment.*", cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"}',
          legendFormat='{{ pod }}',
          format='bytes',
        ),
        panel.timeSeries(
          title='Open File Descriptors',
          query='process_open_fds{service=~"^$Deployment.*", cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"}',
          legendFormat='{{ pod }}',
        ),
      ],
      cols=3,
      rowHeight=10,
      startRow=startRow,
    ),

  averageGeneralCounters(startRow)::
    layout.grid([
      panel.timeSeries(
        title='Process CPU Time',
        query='avg(rate(process_cpu_seconds_total{service=~"^$Deployment.*", cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"}[$__interval]))',
        format='percentunit',
      ),
      panel.timeSeries(
        title='Resident Memory Usage',
        query='avg(process_resident_memory_bytes{service=~"^$Deployment.*", cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"})',
        format='bytes',
      ),
      panel.timeSeries(
        title='Open File Descriptors',
        query='avg(process_open_fds{service=~"^$Deployment.*", cluster=~"$cluster", namespace="$namespace", environment="$environment", stage="$stage"})',
      ),
    ], cols=3, rowHeight=10, startRow=startRow),

  generalRubyCounters(startRow)::
    layout.grid(
      [
        panel.timeSeries(
          title='Process CPU Time',
          query='rate(ruby_process_cpu_seconds_total{pod=~"^$Deployment.*", cluster="$cluster", namespace="$namespace", environment="$environment", stage="$stage"}[$__interval])',
          legendFormat='{{ pod }}',
        ),
        panel.timeSeries(
          title='Resident Memory Usage',
          query='ruby_process_resident_memory_bytes{pod=~"^$Deployment.*", cluster="$cluster", namespace="$namespace", environment="$environment", stage="$stage"}',
          legendFormat='{{ pod }}',
        ),
        panel.timeSeries(
          title='Open File Descriptors',
          query='ruby_process_max_fds{pod=~"^$Deployment.*", cluster="$cluster", namespace="$namespace", environment="$environment", stage="$stage"}',
          legendFormat='{{ pod }}',
        ),
      ],
      cols=3,
      rowHeight=10,
      startRow=startRow,
    ),
}
