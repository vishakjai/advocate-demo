local patroniHelpers = import './lib/patroni-helpers.libsonnet';
local patroniRailsArchetype = import 'service-archetypes/patroni-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  patroniRailsArchetype(
    'patroni',
    extraTags=[
      // disk_performance_monitoring requires disk utilisation metrics are currently reporting correctly for
      // HDD volumes, see https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/10248
      // as such, we only record this utilisation metric on IO subset of the fleet for now.
      'disk_performance_monitoring',

      // pgbouncer_async_replica implies that this service is running a pgbouncer for sidekiq clients
      // in front of a postgres replica
      'pgbouncer_async_replica',

      // postgres_fluent_csvlog_monitoring implies that this service is running fluent-csvlog with vacuum parsing.
      // In future, this should be something we can fold into postgres_with_primaries, but not all postgres instances
      // handle this at present.
      'postgres_fluent_csvlog_monitoring',
    ],
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
    skippedMaturityCriteria: {
      'Developer guides exist in developer documentation': 'patroni is an infrastructure component, developers do not interact with it',
    },
  }
  + patroniHelpers.gitlabcomObservabilityToolingForPatroni('patroni')
  +
  {
    capacityPlanning: {
      components: [
        {
          name: 'memory',
          parameters: {
            changepoints: [
              '2023-04-26',  // https://gitlab.com/gitlab-com/gl-infra/capacity-planning/-/issues/1026#note_1404708663
              '2023-04-28',
            ],

          },
        },
        {
          name: 'pg_int4_id',
          events: [
            {
              date: '2023-03-23',
              name: 'Migrated merge_request_metrics.id',
            },
            {
              date: '2023-04-14',
              name: 'Migrated sent_notifications.id',
            },
            {
              date: '2023-06-15',
              name: 'Migrated note_id in >10 tables',
            },
          ],
          parameters: {
            ignore_outliers: [
              // This is a hack to improve the forecast for this jumpy series of data
              {
                start: '2021-01-01',
                end: '2023-06-17',
              },
            ],
          },
        },
        {
          name: 'pg_primary_cpu',
          parameters: {
            changepoints: [
              '2024-09-23',  // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/18532
            ],
            events: [
              {
                date: '2024-09-23',
                name: 'Upgraded hardware for writer note to C3',
              },
            ],
          },
        },
        {
          name: 'disk_space',
          parameters: {
            ignore_outliers: [
              {
                start: '2022-08-22',
                end: '2022-12-15',
              },
            ],
          },
        },
      ],
    },
  }
)
