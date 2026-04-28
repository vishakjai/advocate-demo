local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local resourceSaturationPoint = (import 'servicemetrics/resource_saturation_point.libsonnet').resourceSaturationPoint;

{
  kube_container_cpu_limit: resourceSaturationPoint({
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: metricsCatalog.findKubeProvisionedServices(first='web'),
    resourceLabels: ['pod', 'container'],
    title: 'Kube Container CPU over-utilization',
    description: |||
      Kubernetes containers can have a limit configured on how much CPU they can consume in
      a burst. If we are at this limit, exceeding the allocated requested resources, we
      should consider revisting the container's HPA configuration.

      When a container is utilizing CPU resources up-to it's configured limit for
      extended periods of time, this could cause it and other running containers to be
      throttled.
    |||,
    grafana_dashboard_uid: 'sat_kube_container_cpu_limit',
    burnRatePeriod: '5m',
    capacityPlanning: { strategy: 'exclude' },
    query: |||
      sum by (%(aggregationLabels)s) (
        rate(container_cpu_usage_seconds_total:labeled{container!="", container!="POD", %(selector)s}[%(rangeInterval)s])
        unless on(pod) (
          kube_pod_labels:labeled{label_gitlab_com_exclude_saturation_point=~"(^|.*[.])kube_container_cpu_limit([.].*|$)", %(selector)s}
        )
      )
      /
      sum by(%(aggregationLabels)s) (
        container_spec_cpu_quota:labeled{container!="", container!="POD", %(selector)s}
        /
        container_spec_cpu_period:labeled{container!="", container!="POD", %(selector)s}
      )
    |||,
    slos: {
      soft: 0.90,
      hard: 0.99,
      alertTriggerDuration: '15m',
    },
  }),
}
