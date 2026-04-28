local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;
local sidekiqHelpers = import './services/lib/sidekiq-helpers.libsonnet';

local commonDefinition = {
  title: 'Horizontal Pod Autoscaler Desired Replicas',
  severity: 's3',
  horizontallyScalable: true,
  appliesTo: std.filter(
    function(service) service != 'sidekiq',
    metricsCatalog.findKubeProvisionedServices(first='web'),
  ),
  description: |||
    The [Horizontal Pod Autoscaler](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/)
    automatically scales the number of Pods in a deployment based on metrics.

    The Horizontal Pod Autoscaler has a configured upper maximum. When this
    limit is reached, the HPA will not increase the number of pods and other
    resource saturation (eg, CPU, memory) may occur.
  |||,
  alertRunbook: 'kube/kubernetes/#hpascalecapability',
  grafana_dashboard_uid: 'sat_kube_horizontalpodautoscaler',
  resourceLabels: ['horizontalpodautoscaler', 'shard'],
  query: |||
    kube_horizontalpodautoscaler_status_desired_replicas:labeled{%(selector)s, shard!~"%(ignored_sidekiq_shards)s", namespace!~"%(ignored_namespaces)s"}
    /
    kube_horizontalpodautoscaler_spec_max_replicas:labeled{%(selector)s, shard!~"%(ignored_sidekiq_shards)s", namespace!~"%(ignored_namespaces)s"}
  |||,
  queryFormatConfig: {
    // Ignore non-autoscaled shards and throttled shards
    ignored_sidekiq_shards: std.join('|', sidekiqHelpers.shards.listFiltered(function(shard) !shard.autoScaling || shard.urgency == 'throttled')),
    ignored_namespaces: 'pubsubbeat',
  },
  slos: {
    soft: 0.90,
    hard: 0.95,
    alertTriggerDuration: '25m',
  },
};

local sidekiqDefinition = commonDefinition {
  title: 'Sidekiq Horizontal Pod Autoscaler Desired Replicas',
  appliesTo: ['sidekiq'],
  grafana_dashboard_uid: 'sat_sidekiq_kube_hpa',
  capacityPlanning: {
    strategy: 'exclude',
  },
};

{
  kube_horizontalpodautoscaler_desired_replicas: resourceSaturationPoint(commonDefinition),
  sidekiq_kube_horizontalpodautoscaler_desired_replicas: resourceSaturationPoint(sidekiqDefinition),
}
