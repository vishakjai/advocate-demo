local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  runwayArchetype(
    // https://gitlab.com/gitlab-com/gl-infra/platform/runway/provisioner/-/blob/cf4c384a449a2c4d58826ee83bfa2ae4c57229b7/config/runtimes/cloud-run/workloads.yml#L455
    type='sample-collector',
    team='observability',
  )
)
