local alerts = import 'alerts/alerts.libsonnet';
local antiAbuseAlerts = import 'alerts/ci-runners-anti-abuse-alerts.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local ciRunnersService = metricsCatalog.getService('ci-runners');

separateMimirRecordingFiles(
  function(_, _, _, tenant) {
    'anti-abuse-alerts': std.manifestYamlDoc(antiAbuseAlerts(tenant)),
  },
  ciRunnersService
)
