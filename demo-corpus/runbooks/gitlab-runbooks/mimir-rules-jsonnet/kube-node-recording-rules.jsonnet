local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;

local kubeNodeRules = import 'recording-rules/kube-node.libsonnet';
local kubeService = metricsCatalog.getService('kube');

separateMimirRecordingFiles(
  function(service, selector, extraArgs, _)
    {
      'kube-node-rules': std.manifestYamlDoc(kubeNodeRules.kubeNodeResourceUsageRules(selector)),
    },
  serviceDefinition=kubeService
)
