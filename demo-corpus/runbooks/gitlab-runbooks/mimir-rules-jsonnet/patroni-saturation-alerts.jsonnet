local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local patroniSaturationAlerts = import 'alerts/patroni-saturation-alerts.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';

// Find all patroni services (patroni, patroni-ci, patroni-sec, patroni-registry)
local patroniServices = std.filter(
  function(service) std.startsWith(service.type, 'patroni'),
  metricsCatalog.services
);

std.foldl(
  function(memo, service)
    memo + separateMimirRecordingFiles(
      function(service, selector, extraArgs, _tenant)
        {
          'patroni-saturation-alerts': std.manifestYamlDoc(patroniSaturationAlerts(selector { type: service.type })),
        },
      serviceDefinition=service { tenants: ['gitlab-gprd'] }
    ),
  patroniServices,
  {}
)
