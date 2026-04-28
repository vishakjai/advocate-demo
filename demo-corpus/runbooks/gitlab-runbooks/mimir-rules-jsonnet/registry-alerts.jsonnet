local alerts = import 'alerts/alerts.libsonnet';
local dbAlerts = import 'alerts/registry-database-alerts.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local registryService = metricsCatalog.getService('patroni-registry');

separateMimirRecordingFiles(
  function(_, selector, _, _) {
    'registry-database-alerts': std.manifestYamlDoc(dbAlerts(selector)),
  },
  registryService
)
