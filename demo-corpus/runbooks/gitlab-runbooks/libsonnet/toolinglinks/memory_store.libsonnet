local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'redis' });
local stackdriverLogs = import './stackdriver_logs.libsonnet';

{
  memoryStore(
    location,
    instance,
    project='gitlab-production',
  )::
    function(options)
      [
        toolingLinkDefinition({
          title: 'Redis Memorystore',
          url: 'https://console.cloud.google.com/memorystore/redis/locations/%(location)s/instances/%(instance)s/details/overview?project=%(project)s' % {
            location: location,
            instance: instance,
            project: project,
          },
        }),
        stackdriverLogs.stackdriverLogsEntry(
          title='Stackdriver Logs: Redis Memorystore %s' % [instance],
          queryHash={
            'resource.type': 'redis_instance',
            'resource.labels.instance_id': 'projects/' + project + '/locations/' + location + '/instances/' + instance,
            'resource.labels.project_id': project,
          },
          project=project
        )(options),
      ],
}
