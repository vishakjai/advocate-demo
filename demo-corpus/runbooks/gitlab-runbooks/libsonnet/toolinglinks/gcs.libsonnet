local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'gcs' });
local stackdriverLogs = import './stackdriver_logs.libsonnet';

{
  gcs(
    bucketName,
    project='gitlab-production',
  )::
    function(options)
      [
        toolingLinkDefinition({
          title: 'GCS',
          url: 'https://console.cloud.google.com/storage/browser/%(bucketName)s?project=%(project)s' % {
            bucketName: bucketName,
            project: project,
          },
        }),
        stackdriverLogs.stackdriverLogsEntry(
          title='Stackdriver Logs: GCS %s' % [bucketName],
          queryHash={
            'resource.type': 'gcs_bucket',
            'resource.labels.bucket_name': bucketName,
          },
          project=project
        )(options),
      ],
}
