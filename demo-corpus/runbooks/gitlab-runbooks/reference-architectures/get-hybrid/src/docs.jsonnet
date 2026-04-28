local services = (import 'gitlab-metrics-config.libsonnet').monitoredServices;
local saturationMonitoring = (import 'gitlab-metrics-config.libsonnet').saturationMonitoring;
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local saturationResource = import 'servicemetrics/saturation-resources.libsonnet';

// This jsonnet file is used by `scripts/generate-reference-architecture-docs.sh` to
// generate documentation that is embedded with the README.md file for this
// reference-architecture.
//
// It will be called when scripts/generate-all-reference-architecture-configs.sh is executed.

local generateSLISnippetForService(service) =
  local slis = service.listServiceLevelIndicators();

  // header +
  std.join('', std.map(function(sli) |||
    | `%(serviceType)s` | `%(name)s` | %(description)s | %(apdexMarker)s | %(errorMarker)s | ✅ |
  ||| % sli {
    serviceType: service.type,
    description: std.strReplace(sli.description, '\n', ' '),
    apdexMarker:
      if sli.hasApdex() then
        '✅' + (if sli.hasApdexSLO() then ' SLO: %g%%' % [sli.monitoringThresholds.apdexScore * 100] else '')
      else
        '-',
    errorMarker:
      if sli.hasErrorRate() then
        '✅' + (if sli.hasErrorRateSLO() then ' SLO: %g%%' % [sli.monitoringThresholds.errorRatio * 100] else '')
      else
        '-',
  }, slis));

local generateSaturationSnippetForResourceType(resourceType) =
  local resource = saturationMonitoring[resourceType];

  local matchingServices = std.filter(function(service) resource.appliesToService(service.type), services);
  local matchingServiceDescriptors = std.map(function(service) '`' + service.type + '`', matchingServices);

  |||
    | `%(resourceType)s` | %(services)s | %(description)s | %(horizontallyScalable)s | %(alertingThreshold)g%% |
  ||| % {
    resourceType: resourceType,
    services: std.join(', ', matchingServiceDescriptors),
    description: std.strReplace(resource.description, '\n', ' '),
    horizontallyScalable: if resource.horizontallyScalable then '✅' else '-',
    alertingThreshold: resource.slos.hard * 100,
  };
{
  'README.snippet-slis.md':
    |||
      ## Service Level Indicators

      | **Service** | **Component** | **Description** | **Apdex** | **Error Ratio** | **Operation Rate** |
      | ----------- | ------------- | --------------- | --------- | --------------- | ------------------ |
    ||| +
    std.join(
      '',
      std.map(
        generateSLISnippetForService, services
      )
    ),

  'README.snippet-saturation.md':
    |||
      ### Monitored Saturation Resources

      | **Resource** | **Applicable Services** | **Description** | **Horizontally Scalable?** | **Alerting Threshold** |
      | ------------ | ----------------------- | --------------- | -------------------------- | -----------------------|
    ||| +
    std.join(
      '',
      std.map(
        generateSaturationSnippetForResourceType, std.sort(std.objectFields(saturationMonitoring))
      )
    ),
}
