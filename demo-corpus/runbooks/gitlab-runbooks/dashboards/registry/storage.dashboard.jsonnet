local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local statPanel = grafana.statPanel;
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

basic.dashboard(
  'Storage Detail',
  tags=['container registry', 'docker', 'registry', 'type:registry'],
)
.addTemplate(templates.gkeCluster)
.addTemplate(templates.stage)
.addTemplate(templates.namespaceGitlab)
.addTemplate(
  template.custom(
    'Deployment',
    'gitlab-registry,',
    'gitlab-registry',
    hide='variable',
  )
)
.addTemplate(template.new(
  'cluster',
  '$PROMETHEUS_DS',
  'label_values(registry_storage_action_seconds_count{environment="$environment"}, cluster)',
  current=null,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
  allValues='.*',
))
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
        query='stackdriver_gcs_bucket_storage_googleapis_com_storage_total_bytes{bucket_name=~"gitlab-.*-registry", environment="$environment"}',
        legendFormat='{{ bucket_name }}',
        format='bytes'
      ),
      panel.timeSeries(
        title='Object Count',
        description='Total number of objects per bucket, grouped by storage class. Values are measured once per day.',
        query='sum by (storage_class) (stackdriver_gcs_bucket_storage_googleapis_com_storage_object_count{bucket_name=~"gitlab-.*-registry", environment="$environment"})',
        legendFormat='{{ storage_class }}'
      ),
      panel.timeSeries(
        title='Storage Use',
        description='Total daily storage in byte*seconds used by the bucket, grouped by storage class.',
        query='sum by (storage_class) (stackdriver_gcs_bucket_storage_googleapis_com_storage_total_byte_seconds{bucket_name=~"gitlab-.*-registry", environment="$environment"})',
        format='Bps',
        yAxisLabel='Bytes/s',
        legendFormat='{{ storage_class }}'
      ),
      panel.timeSeries(
        title='Throughput',
        description='Throughput per API operation group and bucket',
        query=|||
          sum by (bucket_name,method) (
              rate(
                  stackdriver_gcs_bucket_storage_googleapis_com_network_received_bytes_count{bucket_name=~"gitlab-.*-registry", environment="$environment"}[10m]
              )
          )
        |||,
        legend_show=true,
        format='bps',
        yAxisLabel='Bytes/s',
        legendFormat='received - {{ bucket_name }}/{{ method }}'
      )
      .addTarget(
        target.prometheus(
          |||
            sum by (bucket_name,method) (
                rate(
                    stackdriver_gcs_bucket_storage_googleapis_com_network_sent_bytes_count{bucket_name=~"gitlab-.*-registry", environment="$environment"}[10m]
                )
            )
          |||,
          legendFormat='sent - {{ bucket_name }}/{{ method }}'
        )
      ),
      panel.timeSeries(
        title='Backend Retries',
        description='The rate at which requests are retried.',
        query='sum(rate(registry_storage_storage_backend_retries_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]))',
        yAxisLabel='retries/s',
      ),
    ],
    cols=3,
    rowHeight=10,
    startRow=1,
  )
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='RPS (Overall)',
        query='sum(rate(registry_storage_action_seconds_count{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))',
        legend_show=false
      ),
      panel.timeSeries(
        title='RPS (Per Action)',
        query=|||
          sum by (action) (
            rate(registry_storage_action_seconds_count{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval])
          )
        |||,
        legendFormat='{{ action }}'
      ),
      panel.timeSeries(
        title='Estimated p95 Latency (Overall)',
        query=|||
          histogram_quantile(
            0.950000,
            sum by (le) (
              rate(registry_storage_action_seconds_bucket{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval])
            )
          )
        |||,
        format='short',
        legend_show=false
      ),
      panel.timeSeries(
        title='Estimated p95 Latency (Per Action)',
        query=|||
          histogram_quantile(
            0.950000,
            sum by (action,le) (
              rate(registry_storage_action_seconds_bucket{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval])
            )
          )
        |||,
        format='short',
        legendFormat='{{ action }}'
      ),
      panel.timeSeries(
        title='Rate Limited Requests Rate',
        description='Rate of 429 Too Many Requests responses received from GCS',
        query='sum(rate(registry_storage_rate_limit_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))',
        legend_show=false,
        format='ops'
      ),
    ],
    cols=3,
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
        query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code) / sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code)',
        legendFormat='{{ response_code }}',
        format='percentunit',
        max=1,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      panel.timeSeries(
        title='HTTP Requests CACHE HIT (bytes)',
        description='HTTP Requests',
        query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_request_bytes_count{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code)',
        legendFormat='{{ response_code }}',
        format='bytes',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      panel.timeSeries(
        title='Percentage of HTTP Requests CACHE MISS by response',
        description='HTTP Requests',
        query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code) / sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_request_count{environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code)',
        legendFormat='{{ response_code }}',
        format='percentunit',
        max=1,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      panel.timeSeries(
        title='HTTP Requests CACHE MISS (bytes)',
        description='HTTP Requests',
        query='sum(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_request_bytes_count{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}) by (response_code)',
        legendFormat='{{ response_code }}',
        format='bytes',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
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
        query='histogram_quantile(0.6,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}[10m]))',
        legendFormat='{{ response_code }}',
        format='ms',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      panel.timeSeries(
        title='90th Percentile Latency CACHE HIT',
        description='90th Percentile Latency CACHE MISS',
        query='histogram_quantile(0.9,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="HIT", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}[10m]))',
        legendFormat='{{ response_code }}',
        format='ms',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      panel.timeSeries(
        title='60th Percentile Latency CACHE MISS',
        description='60th Percentile Latency CACHE MISS',
        query='histogram_quantile(0.6,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}[10m]))',
        legendFormat='{{ response_code }}',
        format='ms',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
      panel.timeSeries(
        title='90th Percentile Latency CACHE MISS',
        description='90th Percentile Latency CACHE MISS',
        query='histogram_quantile(0.9,rate(stackdriver_https_lb_rule_loadbalancing_googleapis_com_https_backend_latencies_bucket{cache_result="MISS", environment="$environment", forwarding_rule_name=~".*registry-cdn.*"}[10m]))',
        legendFormat='{{ response_code }}',
        format='ms',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='',
        legend_show=true,
        linewidth=2
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=3001,
  )
)

.addPanel(
  row.new(title='Cloud CDN Redirects'),
  gridPos={
    x: 0,
    y: 4000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.percentageTimeSeries(
        title='Percentage of Redirects to CDN',
        description='The percentage of blob HEAD/GET requests redirected to Google Cloud CDN.',
        query=|||
          sum (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage", backend="cdn"}[$__interval]))
          /
          sum (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))
        |||,
        interval='5m',
        intervalFactor=2,
        legend_show=false,
        linewidth=2
      ),
      panel.timeSeries(
        title='Number of Redirects (Per Backend)',
        description='The number of blob HEAD/GET requests redirected to Google Cloud Storage or Google Cloud CDN.',
        query='sum by (backend) (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))',
        format='short',
        legendFormat='{{ backend }}',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='Count',
        linewidth=2
      ),
      panel.percentageTimeSeries(
        title='Percentage of Redirects to CDN Skipped',
        description=|||
          The percentage of blob HEAD/GET requests that were not redirected to Google Cloud CDN because of a given reason:
            - `non_eligible`: This means that the request JWT token was not marked with the `cdn_redirect` flag by Rails. The number
            of JWT tokens marked as such is currently controlled by the `container_registry_cdn_redirect` feature flag (percentage of time).

            - `gcp`: This means that the request originates within GCP, and as such we redirected it to GCS and not CDN.
        |||,
        query=|||
          sum (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage", bypass="true"}[$__interval]))
          /
          sum (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__interval]))
        |||,
        interval='5m',
        intervalFactor=2,
        legend_show=false,
        linewidth=2
      ),
      panel.timeSeries(
        title='Number of Redirects to CDN Skipped (Per Reason)',
        description=|||
          The number of blob HEAD/GET requests that were not redirected to Google Cloud CDN because of a given reason:
            - `non_eligible`: This means that the request JWT token was not marked with the `cdn_redirect` flag by Rails. The number
            of JWT tokens marked as such is currently controlled by the `container_registry_cdn_redirect` feature flag (percentage of time).

            - `gcp`: This means that the request originates within GCP, and as such we redirected it to GCS and not CDN.
        |||,
        query='sum by (bypass_reason) (rate(registry_storage_cdn_redirects_total{environment="$environment", cluster=~"$cluster", stage="$stage", bypass="true"}[$__interval]))',
        format='short',
        legendFormat='{{ bypass_reason }}',
        interval='1m',
        intervalFactor=2,
        yAxisLabel='Count',
        linewidth=2
      ),
    ],
    cols=4,
    rowHeight=10,
    startRow=4001,
  )
)

.addPanel(
  row.new(title='Signed URL caching'),
  gridPos={
    x: 0,
    y: 5000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Requests total',
        description='Total size of objects per bucket. Values are measured once per day.',
        query=|||
          sum(
              rate(
                  registry_storage_urlcache_requests_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]
              )
          ) by (result,reason)
        |||,
        legendFormat='{{result}}/{{reason}}',
      ),
      panel.timeSeries(
        title='Hit ratio',
        description='URLCache hit ratio',
        query=|||
          sum(
              rate(
                  registry_storage_urlcache_requests_total{environment="$environment", cluster=~"$cluster", stage="$stage", result="hit"}[$__rate_interval]
              )
          ) / sum(
              rate(
                  registry_storage_urlcache_requests_total{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]
              )
          )
        |||,
        format='percentunit',
        max=1,
        yAxisLabel='',
        legend_show=true,
        legendFormat='hit ratio',
        linewidth=2
      ),
      panel.timeSeries(
        title='Typical object size',
        description='Average and median size of the URL cache object',
        query=|||
          histogram_quantile(
              0.5,
              sum by (le) (
                  rate(
                      registry_storage_urlcache_object_size_bucket{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]
                      )
                  )
              )
        |||,
        legendFormat='median',
      )
      .addTarget(
        target.prometheus(
          |||
            sum(rate(registry_storage_urlcache_object_size_sum{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]))
            /
            sum(rate(registry_storage_urlcache_object_size_count{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]))
          |||,
          legendFormat='average'
        )
      ),
      basic.heatmap(
        title='Object size',
        description='Heatmap of the URL cache object size',
        query='sum by (le) (rate(registry_storage_urlcache_object_size_bucket{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]))',
        dataFormat='tsbuckets',
        color_cardColor='#00ff00',
        color_colorScheme='Spectral',
        color_mode='spectrum',
        legendFormat='__auto',
        yAxis_format='bytes',
      ),
      panel.timeSeries(
        title='Requests/s for the top-N objects',
        description='Requests/s generated by top N objects',
        query=|||
          sum(
              registry_storage_object_accesses_topn{environment="$environment", cluster=~"$cluster", stage="$stage"}
          ) by (top_n)/60
        |||,
        legendFormat='first {{ top_n }}',
      ),
      basic.heatmap(
        title='Object accesses',
        description='Heatmap of the URL cache objects access counts',
        query='sum by (le) (rate(registry_storage_object_accesses_distribution_bucket{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]))',
        dataFormat='tsbuckets',
        color_cardColor='#00ff00',
        color_colorScheme='Spectral',
        color_mode='spectrum',
        legendFormat='__auto',
        yAxis_format='short',
      ),
      panel.timeSeries(
        title='Access tracker dropped events',
        description='Number of events dropped by access trackere. If >0 access tracker is not able to keep up with amount of data gathered',
        query=|||
          sum(
              rate(
                  registry_storage_access_tracker_dropped_events{environment="$environment", cluster=~"$cluster", stage="$stage"}[$__rate_interval]
              )
          )
        |||,
      ),
    ],
    cols=4,
    rowHeight=10,
    startRow=5001,
  )
)
