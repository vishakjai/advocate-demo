local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local walgBackupsAlerts = import 'alerts/walg-backups-alerts.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local patroniService = metricsCatalog.getService('patroni');

separateMimirRecordingFiles(
  function(service, selector, extraArgs, tenant)
    {
      'walg-backups-alerts': std.manifestYamlDoc(walgBackupsAlerts(tenant, selector)),
    },
)
