local redisHelpers = import './lib/redis-helpers.libsonnet';
local redisArchetype = import 'service-archetypes/redis-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';

metricsCatalog.serviceDefinition(
  redisArchetype(
    type='redis',
    descriptiveName='Persistent Redis',
  )
  {
    tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],
  }
  + redisHelpers.gitlabcomObservabilityToolingForRedis('redis')
  + {
    capacityPlanning: {
      components: [
        {
          name: 'kube_container_memory',
          parameters: {
            ignore_outliers: [
              {
                // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/17753
                start: '2024-03-08',
                end: '2024-03-25',
              },
            ],
          },
        },
        {
          name: 'kube_go_memory',
          parameters: {
            ignore_outliers: [
              {
                // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/17753
                start: '2024-03-08',
                end: '2024-03-25',
              },
            ],
          },
        },
        {
          name: 'redis_secondary_cpu',
          parameters: {
            ignore_outliers: [
              {
                // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/18676
                start: '2024-10-02',
                end: '2024-10-09',
              },
            ],
          },
        },
        {
          name: 'redis_cluster_primary_cpu',
          parameters: {
            ignore_outliers: [
              {
                // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/18676
                start: '2024-10-02',
                end: '2024-10-09',
              },
            ],
          },
        },
      ],
    },
  }
)
