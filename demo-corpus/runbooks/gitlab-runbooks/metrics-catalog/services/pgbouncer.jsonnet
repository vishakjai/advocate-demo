local pgbouncerHelpers = import './lib/pgbouncer-helpers.libsonnet';
local pgbouncerArchetype = import 'service-archetypes/pgbouncer-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  pgbouncerArchetype(
    type='pgbouncer',
    extraTags=[
      'pgbouncer_async_primary',
    ],
  )
  {
    serviceDependencies: {
      patroni: true,
    },
    skippedMaturityCriteria: {
      'Developer guides exist in developer documentation': 'pgbouncer is an infrastructure component, developers do not interact with it',
    },
  }
  + pgbouncerHelpers.gitlabcomObservabilityToolingForPgbouncer('pgbouncer')
  + {
    capacityPlanning+: {
      components: [
        {
          name: 'pgbouncer_sync_primary_pool',
          parameters: {
            ignore_outliers: [
              {
                // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/19608
                start: '2025-04-02',
                end: '2025-05-04',
              },
            ],
          },
        },
      ],
    },
  }
)
