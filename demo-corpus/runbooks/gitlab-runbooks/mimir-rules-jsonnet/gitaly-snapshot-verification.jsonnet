local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local gitalySnapshotVerification = import 'alerts/gitaly-snapshot-verification-alerts.libsonnet';

local rules() = {
  groups: [{
    name: 'Gitaly Snapshot Verification Alerts',
    interval: '1m',
    rules: gitalySnapshotVerification.gitalySnaphotVerificationAlerts(),
  }],
};

separateMimirRecordingFiles(
  function(_service, _selector, _extraArgs, _tenant)
    {
      'gitaly-snapshot-verification-alerts': std.manifestYamlDoc(rules()),
    },
  {
    tenants: ['gitlab-ops'],
    type: 'gitaly-snapshot-verification',
  },
)
