local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local patroniCauseAlerts = import 'alerts/patroni-cause-alerts.libsonnet';

separateMimirRecordingFiles(
  function(service, selector, extraArgs, tenant)
    {
      'patroni-cause-alerts': std.manifestYamlDoc(patroniCauseAlerts(selector, tenant)),
    }
)
