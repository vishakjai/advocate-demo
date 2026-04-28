local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local saturationResources = import 'servicemetrics/saturation-resources.libsonnet';
local saturationRules = import 'servicemetrics/saturation_rules.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local monitoredServices = metricsCatalog.services;

local metricsAndServices = [
  [saturationMetric, service]
  for saturationMetric in std.objectFields(saturationResources)
  for service in saturationResources[saturationMetric].appliesTo
];

local resourcesByService = std.foldl(
  function(memo, tuple)
    local metricName = tuple[0];
    local serviceName = tuple[1];
    local service = std.get(memo, serviceName, {});
    memo {
      [serviceName]: service {
        [metricName]: saturationResources[metricName],
      },
    },
  metricsAndServices,
  {},
);

local filesForSeparateSelector(service, selector, _extraArgs, tenant) =
  local serviceResources = resourcesByService[service.type];
  local extraSourceSelector = selector { type: service.type };
  {
    saturation: std.manifestYamlDoc({
      groups:
        saturationRules.generateSaturationRulesGroup(
          saturationResources=serviceResources,
          extraSourceSelector=extraSourceSelector,
          evaluation='both',  // Drop this when migration to mimir is complete: https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2815
        ),
    }),
    'saturation-alerts': std.manifestYamlDoc({
      groups:
        saturationRules.generateSaturationAuxRulesGroup(
          saturationResources=serviceResources,
          extraSelector=extraSourceSelector,
          evaluation='both',  // Drop this when migration to mimir is complete: https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2815
          tenant=tenant,
        ),
    }),
    'saturation-metadata': std.manifestYamlDoc({
      groups:
        saturationRules.generateSaturationMetadataRulesGroup(
          saturationResources=serviceResources,
          evaluation='both',  // Drop this when migration to mimir is complete: https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2815
          ignoreMetadata=true,  // Drop this when migration to mimir is complete: https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2834
        ),
    }),
  };

std.foldl(
  function(memo, serviceName)
    local serviceDefinition = metricsCatalog.getService(serviceName);
    memo + separateMimirRecordingFiles(filesForSeparateSelector, serviceDefinition),
  std.objectFields(resourcesByService),
  {}
)
