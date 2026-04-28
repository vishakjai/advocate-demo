local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local templates = import 'grafana/templates.libsonnet';
local row = grafana.row;
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local k8sPodsCommon = import 'gitlab-dashboards/kubernetes_pods_common.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';

local env_cluster_ns = 'env=~"$environment", cluster="$cluster", namespace="$namespace"';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';

local generalGraphPanel(
  title,
  fill=0,
  format=null,
  formatY1=null,
  formatY2=null,
  decimals=3,
  description=null,
  linewidth=2,
  sort=0,
      ) =
  panel.basic(
    title,
    linewidth=linewidth,
    description=description,
    legend_min=false,
    legend_max=false,
    legend_avg=false,
    legend_show=true,
    legend_hideEmpty=false,
  );

// clickhouse - pods CPU usage, requests & limits
local clickhouseCPU(
  title,
  container
      ) =
  generalGraphPanel(title)
  .addTarget(
    target.prometheus(
      |||
        sum(
            rate(container_cpu_usage_seconds_total{%(env_cluster_ns)s, pod=~"cluster-.*", container="%(container)s"}[2m])
        ) by (pod)
      ||| % { env_cluster_ns: env_cluster_ns, container: container },
      legendFormat='usage: {{ pod }}'
    )
  )
  .addTarget(
    target.prometheus(
      |||
        kube_pod_container_resource_limits{%(env_cluster_ns)s, pod=~"cluster-.*", resource="cpu", container="%(container)s"}
      ||| % { env_cluster_ns: env_cluster_ns, container: container },
      legendFormat='limit: {{ pod }}'
    )
  )
  .addTarget(
    target.prometheus(
      |||
        kube_pod_container_resource_requests{%(env_cluster_ns)s, pod=~"cluster-.*", resource="cpu", container="%(container)s"}
      ||| % { env_cluster_ns: env_cluster_ns, container: container },
      legendFormat='request: {{ pod }}'
    )
  );

// clickhouse - pods CPU throttling%
local clickhouseCPUThrottling(
  title,
  container,
      ) =
  generalGraphPanel(title)
  .addTarget(
    target.prometheus(
      |||
        100*(
            sum(
                rate(container_cpu_cfs_throttled_periods_total{%(env_cluster_ns)s, pod=~"cluster-.*", container="%(container)s"}[2m])
            ) by (pod)
            /
            sum(
                rate(container_cpu_cfs_periods_total{%(env_cluster_ns)s, pod=~"cluster-.*", container="%(container)s"}[2m])
            ) by (pod)
        )
      ||| % { env_cluster_ns: env_cluster_ns, container: container },
      legendFormat='{{ pod }}'
    )
  );

// clickhouse - pods Memory usage, requests & limits
local clickhouseMemory(
  title,
  container
      ) =
  generalGraphPanel(title)
  .addTarget(
    target.prometheus(
      |||
        sum(
            rate(container_memory_working_set_bytes{%(env_cluster_ns)s, pod=~"cluster-.*", container="%(container)s"}[2m])
        ) by (pod) / (1024*1024*1024)
      ||| % { env_cluster_ns: env_cluster_ns, container: container },
      legendFormat='usage: {{ pod }}'
    )
  )
  .addTarget(
    target.prometheus(
      |||
        kube_pod_container_resource_limits{%(env_cluster_ns)s, pod=~"cluster-.*", resource="memory", container="%(container)s"} / (1024*1024*1024)
      ||| % { env_cluster_ns: env_cluster_ns, container: container },
      legendFormat='limit: {{ pod }}'
    )
  )
  .addTarget(
    target.prometheus(
      |||
        kube_pod_container_resource_requests{%(env_cluster_ns)s, pod=~"cluster-.*", resource="memory", container="%(container)s"} / (1024*1024*1024)
      ||| % { env_cluster_ns: env_cluster_ns, container: container },
      legendFormat='request: {{ pod }}'
    )
  );

// clickhouse - pods PVC storage usage & capacity
local clickhousePVCStorage(
  title,
  pvcNameRe,
      ) =
  generalGraphPanel(
    title,
  )
  .addTarget(
    target.prometheus(
      |||
        sum(
            kubelet_volume_stats_used_bytes{%(env_cluster_ns)s, persistentvolumeclaim=~"%(pvcNameRe)s"}
        ) by (persistentvolumeclaim) / (1024*1024*1024)
      ||| % { env_cluster_ns: env_cluster_ns, pvcNameRe: pvcNameRe },
      legendFormat='used: {{ persistentvolumeclaim }}'
    )
  )
  .addTarget(
    target.prometheus(
      |||
        sum(
            kubelet_volume_stats_capacity_bytes{%(env_cluster_ns)s, persistentvolumeclaim=~"%(pvcNameRe)s"}
        ) by (persistentvolumeclaim) / (1024*1024*1024)
      ||| % { env_cluster_ns: env_cluster_ns, pvcNameRe: pvcNameRe },
      legendFormat='capacity: {{ persistentvolumeclaim }}'
    )
  );

basic.dashboard(
  'Clickhouse',
  tags=[
    'gitlab-observability',
  ],
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-observability')
)
.addTemplate(templates.Node)
.addTemplate(
  template.custom(
    name='environment',
    label='Environment',
    query='gstg,gprd',
    current='gprd',
  )
)
.addTemplate(
  template.new(
    'cluster',
    '$PROMETHEUS_DS',
    'label_values(kube_pod_container_info{env="$environment", cluster=~"opstrace-.*"}, cluster)',
    label='Cluster',
    refresh='load',
    sort=1,
  )
)
.addTemplate(
  template.new(
    'namespace',
    '$PROMETHEUS_DS',
    'label_values(kube_statefulset_status_replicas{env="gprd", cluster=~"opstrace-.*", statefulset=~"cluster-.*"}, namespace)',
    label='Namespace',
    refresh='time',
    multi=false,
    includeAll=false,
  )
)
.addPanel(
  row.new(title='ClickHouse - Deployed Version(s)'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Active Version - clickhouse-server',
        query=|||
          count(
              kube_pod_container_info{%(env_cluster_ns)s, pod=~"cluster-.*", container="clickhouse-server"}
          ) by (image)
        ||| % { env_cluster_ns: env_cluster_ns },
        legendFormat='{{ image }}',
      ),
      panel.timeSeries(
        title='Active Version - clickhouse-keeper',
        query=|||
          count(
              kube_pod_container_info{%(env_cluster_ns)s, pod=~"cluster-.*", container="clickhouse-keeper"}
          ) by (image)
        ||| % { env_cluster_ns: env_cluster_ns },
        legendFormat='{{ image }}',
      ),
    ],
    cols=2,
    rowHeight=8,
    startRow=1,
  )
)
.addPanel(
  row.new(title='ClickHouse - CPU'),
  gridPos={ x: 0, y: 100, w: 24, h: 1 },
)
.addPanels(
  layout.grid([
    clickhouseCPU(title='CPU (cores) - Server', container='clickhouse-server'),
    clickhouseCPU(title='CPU (cores) - Keeper', container='clickhouse-keeper'),
    clickhouseCPU(title='CPU (cores) - ZK Exporter', container='zookeeper-exporter'),
    clickhouseCPUThrottling(title='Throttled % - Server', container='clickhouse-server'),
    clickhouseCPUThrottling(title='Throttled % - Keeper', container='clickhouse-keeper'),
    clickhouseCPUThrottling(title='Throttled % - ZK Exporter', container='zookeeper-exporter'),
  ], cols=3, rowHeight=12, startRow=101)
)
.addPanel(
  row.new(title='ClickHouse - Memory'),
  gridPos={ x: 0, y: 200, w: 24, h: 1 },
)
.addPanels(
  layout.grid([
    clickhouseMemory(title='Memory (GB) - Server', container='clickhouse-server'),
    clickhouseMemory(title='Memory (GB) - Keeper', container='clickhouse-keeper'),
    clickhouseMemory(title='Memory (GB) - ZK Exporter', container='zookeeper-exporter'),
  ], cols=3, rowHeight=12, startRow=201)
)
.addPanel(
  row.new(title='ClickHouse - Storage'),
  gridPos={ x: 0, y: 300, w: 24, h: 1 },
)
.addPanels(
  layout.grid([
    clickhousePVCStorage(title='Volume Size (GB) - Data', pvcNameRe='data-cluster-.*'),
    clickhousePVCStorage(title='Volume Size (GB) - Logs', pvcNameRe='logs-cluster-.*'),
    clickhousePVCStorage(title='Volume Size (GB) - Keeper Logs', pvcNameRe='keeper-logs-cluster-.*'),
  ], cols=3, rowHeight=12, startRow=301)
)
.addPanel(
  row.new(title='ClickHouse - Replication'),
  gridPos={ x: 0, y: 400, w: 24, h: 1 },
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Number of read-only replicas',
        query=|||
          ClickHouseMetrics_ReadonlyReplica{%(env_cluster_ns)s}
        ||| % { env_cluster_ns: env_cluster_ns },
        legendFormat='{{ pod }}',
      ),
      panel.timeSeries(
        title='Number of detached parts',
        query=|||
          ClickHouseAsyncMetrics_NumberOfDetachedParts{%(env_cluster_ns)s}
        ||| % { env_cluster_ns: env_cluster_ns },
        legendFormat='{{ pod }}',
      ),
    ],
    cols=2,
    rowHeight=12,
    startRow=401,
  )
)
