local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

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
    unit=format,
    description=description,
    legend_min=false,
    legend_avg=false,
    legend_rightSide=true,
    legend_hideEmpty=false,
  );

local env_cluster_node = 'env=~"$environment", cluster="$cluster", node=~"^$Node.*$"';
local env_cluster_node_ns = env_cluster_node + ', namespace="$namespace"';
local env_cluster_ns = 'env=~"$environment", cluster="$cluster", namespace="$namespace"';

{
  version(startRow, deploymentKind='Deployment')::
    layout.grid(
      [
        panel.timeSeries(
          title='Active Version',
          query='count(kube_pod_container_info{' + env_cluster_node_ns + ', container_id!="", pod=~"^$' + deploymentKind + '.*$"}) by (image)',
          legendFormat='{{ image }}',
        ),
        panel.timeSeries(
          title='Active Replicaset',
          query='avg(kube_replicaset_spec_replicas{' + env_cluster_ns + ', replicaset=~"^$Deployment.*"}) by (replicaset)',
          legendFormat='{{ replicaset }}',
          legend_rightSide=true,
        ),
      ],
      cols=2,
      rowHeight=5,
      startRow=startRow,
    ),

  deployment(startRow, deploymentKind='Deployment')::
    layout.grid([
      basic.gaugePanel(
        'Deployment Memory Usage',
        query='sum (container_memory_working_set_bytes{' + env_cluster_node_ns + ', pod=~"^$' + deploymentKind + '.*$"}) / sum (kube_node_status_allocatable{resource="memory", unit= "byte", env=~"$environment", node=~"^$Node.*$"}) * 100',
        instant=false,
        unit='percent',
        color=[
          { color: 'green', value: null },
          { color: 'orange', value: 65 },
          { color: 'red', value: 90 },
        ],
      ),
      basic.gaugePanel(
        'Deployment CPU Usage',
        query='sum (rate (container_cpu_usage_seconds_total{' + env_cluster_node + ', pod=~"^$' + deploymentKind + '.*$"}[2m])) / sum (machine_cpu_cores{' + env_cluster_node + '}) * 100',
        instant=false,
        unit='percentunit',
        max=1,
        color=[
          { color: 'green', value: null },
          { color: 'orange', value: 0.65 },
          { color: 'red', value: 0.90 },
        ],
      ),
      basic.gaugePanel(
        'Unavailable Replicas',
        query='((sum(kube_deployment_status_replicas{' + env_cluster_ns + ', deployment=~"$Deployment.*"}) or vector(0)) - ((sum(kube_deployment_status_replicas_available{' + env_cluster_ns + ', deployment=~"$Deployment.*"}) or vector(0)))) / (sum(kube_deployment_status_replicas{' + env_cluster_ns + ', deployment=~"$Deployment.*"}) or vector(0))',
        instant=false,
        unit='none',
        decimals=0,
        color=[
          { color: 'green', value: null },
          { color: 'orange', value: 1 },
          { color: 'red', value: 30 },
        ],
      ),
    ], cols=3, rowHeight=5, startRow=startRow),

  status(startRow, deploymentKind='Deployment')::
    layout.grid([
      basic.statPanel(
        '',
        'Memory Used',
        color='',
        query='sum (container_memory_working_set_bytes{' + env_cluster_node_ns + ', pod=~"^$' + deploymentKind + '.*$"})',
        instant=false,
        unit='bytes',
        decimals=2,
        colorMode='none',
      ),
      basic.statPanel(
        '',
        'Memory Total (cluster)',
        color='',
        query='sum (kube_node_status_allocatable{env=~"$environment", cluster="$cluster", resource="memory", unit="byte"})',
        instant=false,
        unit='bytes',
        decimals=2,
        colorMode='none',
      ),
      basic.statPanel(
        '',
        'CPU Cores Used',
        color='',
        query='sum (rate (container_cpu_usage_seconds_total{' + env_cluster_node_ns + ', pod=~"^$' + deploymentKind + '.*$"}[1m]))',
        instant=false,
        unit='none',
        decimals=2,
        colorMode='none'
      ),
      basic.statPanel(
        '',
        'CPU Cores Total (cluster)',
        color='',
        query='sum (machine_cpu_cores{env=~"$environment", cluster="$cluster"})',
        instant=false,
        unit='none',
        colorMode='none',
      ),
      basic.statPanel(
        '',
        'Pods available (cluster)',
        color='',
        query='sum(kube_deployment_status_replicas_available{' + env_cluster_ns + ', deployment=~"$Deployment.*"})',
        instant=false,
        unit='none',
        colorMode='none',
      ),
      basic.statPanel(
        '',
        'Pods total (cluster)',
        color='',
        query='sum(kube_deployment_status_replicas{' + env_cluster_ns + ', deployment=~"$Deployment.*"})',
        instant=false,
        unit='none',
        colorMode='none',
      ),
    ], cols=6, rowHeight=3, startRow=startRow + 1),

  cpu(startRow, deploymentKind='Deployment')::
    layout.grid(
      [
        generalGraphPanel(
          'Usage',
          format='none',
        )
        .addTarget(
          target.prometheus(
            'sum (rate (container_cpu_usage_seconds_total{' + env_cluster_node_ns + ', image!="", pod=~"^$' + deploymentKind + '.*$"}[1m])) by (pod,node)',
            legendFormat='real: {{ pod }}',
          )
        )
        .addTarget(
          target.prometheus(
            'sum (kube_pod_container_resource_requests{' + env_cluster_node_ns + ', resource="cpu", unit="core", pod=~"^$' + deploymentKind + '.*$"}) by (pod,node)',
            legendFormat='rqst: {{ pod }}',
          )
        )
        .addYaxis(
          label='cores',
        ),
        panel.table(
          'Quota',
          styles=[
            {
              type: 'hidden',
              pattern: 'Time',
              alias: 'Time',
            },
            {
              unit: 'short',
              type: 'number',
              alias: 'Pod',
              decimals: 0,
              pattern: 'pod',
              link: true,
              linkUrl: '/d/kubernetes-resources-pod/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell',
              linkTooltip: 'Drill Down',

            },
            {
              unit: 'short',
              type: 'number',
              alias: 'CPU Usage',
              decimals: 3,
              pattern: 'Value #A',
            },
            {
              unit: 'short',
              type: 'number',
              alias: 'CPU Requests',
              decimals: 3,
              pattern: 'Value #B',
            },
            {
              unit: 'percentunit',
              type: 'number',
              alias: 'CPU Usage %',
              decimals: 0,
              pattern: 'Value #C',
            },
          ],
        )
        .addTarget(
          target.prometheus(
            'sum(label_replace(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{env=~"$environment"}, "pod", "$1", "pod", "(.*)") * on(namespace,pod) group_left(workload) (mixin_pod_workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"} or mixin_pod:workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"})) by (pod)',
            format='table',
            instant=true,
          )
        )
        .addTarget(
          target.prometheus(
            'sum(kube_pod_container_resource_requests{resource="cpu", unit="core", env=~"$environment"} * on(namespace,pod) group_left(workload) (mixin_pod_workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"} or mixin_pod:workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"}) ) by (pod)',
            format='table',
            instant=true,
          )
        )
        .addTarget(
          target.prometheus(
            'sum(label_replace(namespace_pod_container:container_cpu_usage_seconds_total:sum_rate{env=~"$environment"}, "pod", "$1", "pod", "(.*)") * on(pod) group_left(workload) (mixin_pod_workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"} or mixin_pod:workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"})) by (pod)\n/\nsum(kube_pod_container_resource_requests{resource="cpu", unit="core", env=~"$environment"} * on(pod) group_left(workload) (mixin_pod_workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"} or mixin_pod:workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"})) by (pod)',
            format='table',
            instant=true,
          )
        ),
      ],
      cols=1,
      rowHeight=10,
      startRow=startRow,
    ),

  memory(deploymentKind='Deployment', startRow, container)::
    layout.grid(
      [
        generalGraphPanel(
          'Usage',
          format='bytes',
        )
        .addTarget(
          target.prometheus(
            'sum (container_memory_working_set_bytes{' + env_cluster_node_ns + ', id!="/",pod=~"^$' + deploymentKind + '.*$", container="%(container)s"}) by (pod)' % { container: container },
            legendFormat='real: {{ pod }}',
          )
        ),
        panel.table(
          'Quota',
          styles=[
            {
              type: 'hidden',
              pattern: 'Time',
              alias: 'Time',
            },
            {
              unit: 'short',
              type: 'number',
              alias: 'Pod',
              decimals: 0,
              pattern: 'pod',
              link: true,
              linkUrl: '/d/kubernetes-resources-pod/k8s-resources-pod?var-datasource=$datasource&var-cluster=$cluster&var-namespace=$namespace&var-pod=$__cell',
              linkTooltip: 'Drill Down',

            },
            {
              unit: 'bytes',
              type: 'number',
              alias: 'Memory Usage',
              decimals: 2,
              pattern: 'Value #A',
            },
            {
              unit: 'bytes',
              type: 'number',
              alias: 'Memory Requests',
              decimals: 2,
              pattern: 'Value #B',
            },
            {
              unit: 'percentunit',
              type: 'number',
              alias: 'Memory Usage %',
              decimals: 1,
              pattern: 'Value #C',
            },
          ],
        )
        .addTarget(
          target.prometheus(
            'sum(label_replace(container_memory_usage_bytes{env=~"$environment", container!=""}, "pod", "$1", "pod", "(.*)") * on(pod) group_left(workload) (mixin_pod_workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"} or mixin_pod:workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"})) by (pod)',
            format='table',
            instant=true,
          )
        )
        .addTarget(
          target.prometheus(
            'sum(kube_pod_container_resource_requests{resource="memory", unit="byte", env=~"$environment"} * on(pod) group_left(workload) (mixin_pod_workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"} or mixin_pod:workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"})) by (pod)',
            format='table',
            instant=true,
          )
        )
        .addTarget(
          target.prometheus(
            'sum(label_replace(container_memory_usage_bytes{env=~"$environment", container!=""}, "pod", "$1", "pod", "(.*)") * on(pod) group_left(workload) (mixin_pod_workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"} or mixin_pod:workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"}) by (pod) /sum(kube_pod_container_resource_requests{resource="memory", unit="byte", env=~"$environment"} * on(pod) group_left(workload) (mixin_pod_workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"} or mixin_pod:workload{' + env_cluster_ns + ', workload=~"^$' + deploymentKind + '.*"}) by (pod)',
            format='table',
            instant=true,
          )
        ),
      ],
      cols=1,
      rowHeight=10,
      startRow=startRow,
    ),

  network(deploymentKind='Deployment', startRow)::
    layout.grid(
      [
        generalGraphPanel(
          'All processes network I/O',
          format='Bps',
          fill=10,
        )
        .addTarget(
          target.prometheus(
            'sum (rate (container_network_receive_bytes_total{' + env_cluster_node_ns + ', id!="/",pod=~"^$' + deploymentKind + '.*$"}[1m])) by (pod)',
            legendFormat='-> {{ pod }}',
          )
        )
        .addTarget(
          target.prometheus(
            '- sum( rate (container_network_transmit_bytes_total{' + env_cluster_node_ns + ', id!="/",pod=~"^$' + deploymentKind + '.*$"}[1m])) by (pod)',
            legendFormat='<- {{ pod }}',
          )
        ),
      ],
      cols=1,
      rowHeight=10,
      startRow=startRow,
    ),
}
