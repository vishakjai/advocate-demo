local patroniHelpers = import './lib/patroni-helpers.libsonnet';
local patroniRailsArchetype = import 'service-archetypes/patroni-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;

metricsCatalog.serviceDefinition(
  patroniRailsArchetype(
    type='patroni-ci',
    serviceDependencies={
      patroni: true,
    },

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
    serviceLevelIndicators+: {
      rails_replica_sql+: {
        apdex: histogramApdex(
          histogram='gitlab_sql_replica_duration_seconds_bucket',
          selector={ type: { ne: 'sidekiq' }, db_config_name: 'ci_replica' },
          satisfiedThreshold=0.1,
          toleratedThreshold=0.25
        ),
      },
    },
    skippedMaturityCriteria: {
      'Developer guides exist in developer documentation': 'patroni is an infrastructure component, developers do not interact with it',
    },
  }
  + patroniHelpers.gitlabcomObservabilityToolingForPatroni('patroni-ci')
  +
  {
    capacityPlanning: {
      components: [
        {
          name: 'memory',
          parameters: {
            changepoints: [
              '2023-04-26',  // Introduction of backup node: https://gitlab.com/gitlab-com/gl-infra/capacity-planning/-/issues/1026#note_1404708663
              '2023-04-28',
              '2023-11-27',  // Putting v16 nodes into service with different memory configuration https://gitlab.com/gitlab-com/gl-infra/chef-repo/-/blob/master/roles/gprd-base-db-patroni-ci-v16.json?ref_type=heads#L394 https://gitlab.com/gitlab-com/gl-infra/production/-/issues/18639
            ],
          },
        },
        {
          name: 'pg_int4_id',
          events: [
            {
              date: '2023-03-30',
              name: 'Migrated ci_build_needs.id',
            },
            {
              date: '2023-06-28',
              name: 'Migrated ci_pipeline_variables.id',
            },
          ],
          parameters: {
            ignore_outliers: [
              // This is a hack to improve the forecast for this jumpy series of data
              {
                start: '2021-01-01',
                end: '2023-06-20',
              },
            ],
          },
        },
        {
          name: 'pg_primary_cpu',
          events: [
            {
              date: '2023-02-19',
              name: 'LWLock contention',
              references: [
                {
                  title: 'LWLock contention',
                  ref: 'https://gitlab.com/gitlab-com/gl-infra/capacity-planning-trackers/gitlab-com/-/issues/1668#note_1801803894',
                },
              ],
            },
          ],
          parameters: {
            ignore_outliers: [
              {
                start: '2024-02-19',
                end: '2024-02-21',
              },
            ],
          },
        },
        {
          name: 'disk_space',
          parameters: {
            ignore_outliers: [
              {
                start: '2021-01-01',
                end: '2022-10-01',
              },
            ],
          },
        },
        {
          name: 'pg_btree_bloat',
          parameters: {
            changepoints: [
              '2023-08-12',
            ],
          },
          events: [
            {
              date: '2023-08-12',
              name: 'PG Upgrade',
            },
          ],
        },
      ],
    },
  }
)
