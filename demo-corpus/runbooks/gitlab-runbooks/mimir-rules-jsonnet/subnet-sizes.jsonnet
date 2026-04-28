local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local subnetSizes = import 'recording-rules/subnet-sizes.libsonnet';

separateMimirRecordingFiles(
  function(service, selector, extraArgs, _)
    {
      [if std.objectHas(subnetSizes, selector.env) then 'subnet-sizes']: std.manifestYamlDoc({ groups: std.get(subnetSizes, selector.env) }),
    }
)
