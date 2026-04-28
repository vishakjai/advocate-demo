local redisHelpers = import './lib/redis-helpers.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local redisArchetype = import 'service-archetypes/redis-rails-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis-sidekiq',
    railsStorageSelector=redisHelpers.storageSelector('queues'),
    descriptiveName='Redis Sidekiq'
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
    monitoring: { shard: { enabled: true } },
    serviceLevelIndicators+: {
      rails_redis_client+: {
        description: |||
          Aggregation of all Redis operations issued to the Redis Sidekiq service from the Rails codebase.

          If this SLI is experiencing a degradation, it may be caused by saturation in the Redis Sidekiq instance caused by
          high traffic volumes from Sidekiq clients (Rails or other sidekiq jobs), or very large messages being delivered
          via Sidekiq.

          Reviewing Sidekiq job logs may help the investigation.
        |||,
      },
    },
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis-sidekiq')
  + {
    capacityPlanning: {
      local shards = ['default', 'catchall_a', 'catchall_b'],
      saturation_dimensions: [
        { selector: selectors.serializeHash({ shard: shard }) }
        for shard in shards
      ] + [
        {
          selector: selectors.serializeHash({ shard: { noneOf: shards } }),
          label: 'shard=rest-aggregated',
        },
      ],
      saturation_dimensions_keep_aggregate: false,
      components: [
        {
          name: 'redis_primary_cpu',
          parameters: {
            changepoints: ['2023-08-22', '2023-09-27'],
            ignore_outliers: [
              {
                // https://gitlab.com/gitlab-com/gl-infra/capacity-planning-trackers/gitlab-com/-/issues/1452#note_1700126988
                start: '2023-12-16',
                end: '2023-12-19',
              },
            ],
          },
          events: [
            {
              date: '2023-08-22',
              name: 'A code change increased baseline load',
              references: [
                {
                  title: 'gitlab-org/gitlab!119792',
                  ref: 'https://gitlab.com/gitlab-org/gitlab/-/merge_requests/119792',
                },
              ],
            },
            {
              date: '2023-09-27',
              name: 'Shifting job deduplication out reduced baseline load',
              references: [
                {
                  title: '&431',
                  ref: 'https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/431#note_1582594368',
                },
              ],
            },
            {
              date: '2023-12-16',
              name: 'Incident: SidekiqQueueTooLarge default queue',
              references: [
                {
                  title: 'incident',
                  ref: 'https://gitlab.com/gitlab-com/gl-infra/production/-/issues/17294#note_1698952114',
                },
              ],
            },
          ],
        },
      ],
    },
  }
)
