local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local kubeCauseAlerts = import 'alerts/kube-cause-alerts.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

std.foldl(
  function(memo, serviceName)
    local service = metricsCatalog.getService(serviceName);
    memo + separateMimirRecordingFiles(
      function(service, selector, extraArgs, tenant)
        {
          'kube-cause-alerts': std.manifestYamlDoc(kubeCauseAlerts(selector { type: serviceName }, tenant)),
        },
      serviceDefinition=service
    ),
  metricsCatalog.findKubeProvisionedServices(),
  {}
)
