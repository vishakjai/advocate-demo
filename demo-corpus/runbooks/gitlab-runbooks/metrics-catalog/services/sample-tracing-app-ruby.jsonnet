local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  runwayArchetype(
    // https://gitlab.com/gitlab-com/gl-infra/platform/runway/provisioner/-/blob/main/config/runtimes/cloud-run/workloads.yml?ref_type=heads#L450
    type='tracing-app-ruby',
    team='observability',
  )
)
