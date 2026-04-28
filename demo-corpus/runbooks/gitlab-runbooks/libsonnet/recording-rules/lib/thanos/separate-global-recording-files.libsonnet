local objects = import 'utils/objects.libsonnet';

{
  separateGlobalRecordingFiles(
    filesForSeparateSelector,
    metricsConfig=(import 'gitlab-metrics-config.libsonnet'),
    pathFormat='%(baseName)s-%(envName)s.yml',
  )::
    std.foldl(
      function(memo, envName)
        memo + objects.transformKeys(
          function(baseName)
            pathFormat % {
              baseName: baseName,
              envName: envName,
            },
          filesForSeparateSelector(metricsConfig.separateGlobalRecordingSelectors[envName])
        ),
      std.objectFields(metricsConfig.separateGlobalRecordingSelectors),
      {},
    ),
}
