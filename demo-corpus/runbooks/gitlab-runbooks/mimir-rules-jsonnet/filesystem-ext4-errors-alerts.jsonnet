local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local filesystemExt4ErrorsAlerts = import 'alerts/filesystem-ext4-errors-alerts.libsonnet';

local rules() = {
  groups: [{
    name: 'Filesystem EXT4 Errors Alerts',
    interval: '1m',
    rules: filesystemExt4ErrorsAlerts.filesystemExt4ErrorsAlerts(),
  }],
};

separateMimirRecordingFiles(
  function(_service, _selector, _extraArgs, _tenant)
    {
      'filesystem-ext4-errors-alerts': std.manifestYamlDoc(rules()),
    },
  {
    tenants: ['gitlab-gprd'],
    type: 'gitaly',
  },
)
