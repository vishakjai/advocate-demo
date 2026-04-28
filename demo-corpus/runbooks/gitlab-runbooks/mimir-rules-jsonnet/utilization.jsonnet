local labelTaxonomy = import 'label-taxonomy/label-taxonomy.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local utilizationMetrics = import 'servicemetrics/utilization-metrics.libsonnet';
local utilizationRules = import 'servicemetrics/utilization_rules.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local monitoredServices = metricsCatalog.services;


local l = labelTaxonomy.labels;
local environmentLabels = labelTaxonomy.labelTaxonomy(l.environmentThanos | l.tier | l.service | l.stage);

local filesForSeparateSelector(serviceUtilizationMetrics) =
  function(service, selector, _extraArgs, _)
    local serviceSelector = selector { type: service.type };
    utilizationRules.generateUtilizationRules(
      serviceUtilizationMetrics,
      environmentLabels=environmentLabels,
      extraSelector=serviceSelector,
      filename='utilization'
    );

local metricsAndServices = [
  [utilizationMetric, service]
  for utilizationMetric in std.objectFields(utilizationMetrics)
  for service in utilizationMetrics[utilizationMetric].appliesTo
];

local metricsByService = std.foldl(
  function(memo, tuple)
    local metricName = tuple[0];
    local serviceName = tuple[1];
    local service = std.get(memo, serviceName, {});
    memo {
      [serviceName]: service {
        [metricName]: utilizationMetrics[metricName],
      },
    },
  metricsAndServices,
  {}
);

std.foldl(
  function(memo, serviceName)
    local serviceDefinition = metricsCatalog.getService(serviceName);
    memo + separateMimirRecordingFiles(filesForSeparateSelector(metricsByService[serviceName]), serviceDefinition),
  std.objectFields(metricsByService),
  {}
)
