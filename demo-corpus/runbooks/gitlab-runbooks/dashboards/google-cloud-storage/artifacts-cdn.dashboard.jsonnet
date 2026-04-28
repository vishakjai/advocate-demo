local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local statPanel = grafana.statPanel;
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Artifact CDN Detail',
  tags=['google-cloud-storage', 'type:google-cloud-storage'],
)
.addPanel(
  row.new(title='GCS Bucket'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Total Size',
        description='Total size of objects per bucket. Values are measured once per day.',
        query='stackdriver_gcs_bucket_storage_googleapis_com_storage_total_bytes{bucket_name=~"gitlab-.*-artifacts", environment="$environment"}',
        legendFormat='{{ bucket_name }}',
        format='bytes'
      ),
    ],
    cols=1,
    rowHeight=10,
    startRow=1001,
  )
)
.addPanel(
  row.new(title='Cloud CDN Requests'),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Percentage of HTTP Requests CACHE HIT by response',
        description='HTTP Requests',
        query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}) by (response_code) / sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}) by (response_code)',
        legendFormat='{{ response_code }}',
        format='percentunit',
        max=1,
        yAxisLabel='',
        linewidth=2
      ),
      panel.timeSeries(
        title='HTTP Requests CACHE HIT (bytes)',
        description='HTTP Requests',
        query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_request_bytes_count{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}) by (response_code)',
        legendFormat='{{ response_code }}',
        format='bytes',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        linewidth=2
      ),
      panel.timeSeries(
        title='Percentage of HTTP Requests CACHE MISS by response',
        description='HTTP Requests',
        query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}) by (response_code) / sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}) by (response_code)',
        legendFormat='{{ response_code }}',
        format='percentunit',
        max=1,
        yAxisLabel='',
        linewidth=2
      ),
      panel.timeSeries(
        title='HTTP Requests CACHE MISS (bytes)',
        description='HTTP Requests',
        query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_request_bytes_count{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}) by (response_code)',
        legendFormat='{{ response_code }}',
        format='bytes',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        linewidth=2
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=2001,
  )
)
.addPanel(
  row.new(title='Cloud CDN Latencies'),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='60th Percentile Latency CACHE HIT',
        description='60th Percentile Latency CACHE MISS',
        query='histogram_quantile(0.6,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}[10m]))',
        legendFormat='{{ response_code }}',
        format='ms',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        linewidth=2
      ),
      panel.timeSeries(
        title='90th Percentile Latency CACHE HIT',
        description='90th Percentile Latency CACHE MISS',
        query='histogram_quantile(0.9,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}[10m]))',
        legendFormat='{{ response_code }}',
        format='ms',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        linewidth=2
      ),
      panel.timeSeries(
        title='60th Percentile Latency CACHE MISS',
        description='60th Percentile Latency CACHE MISS',
        query='histogram_quantile(0.6,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}[10m]))',
        legendFormat='{{ response_code }}',
        format='ms',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        linewidth=2
      ),
      panel.timeSeries(
        title='90th Percentile Latency CACHE MISS',
        description='90th Percentile Latency CACHE MISS',
        query='histogram_quantile(0.9,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*artifacts-cdn.*"}[10m]))',
        legendFormat='{{ response_code }}',
        format='ms',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        linewidth=2
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=3001,
  )
)
