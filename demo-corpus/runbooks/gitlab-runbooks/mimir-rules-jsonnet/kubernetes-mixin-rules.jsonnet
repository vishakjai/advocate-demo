local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local selectors = import 'promql/selectors.libsonnet';

local kubeService = metricsCatalog.getService('kube');
local kubernetesMixin = import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet';

local mixin(selector) = kubernetesMixin {
  _config+:: {
    cadvisorSelector: selectors.serializeHash(selector {
      job: 'kubelet',
    }),
    kubeletSelector: selectors.serializeHash(selector {
      job: 'kubelet',
    }),
    kubeStateMetricsSelector: selectors.serializeHash(selector {
      job: 'kube-state-metrics',
    }),
    nodeExporterSelector: selectors.serializeHash(selector {
      job: 'node-exporter',
    }),
    kubeSchedulerSelector: selectors.serializeHash(selector {
      job: 'kube-scheduler',
    }),
    kubeControllerManagerSelector: selectors.serializeHash(selector {
      job: 'kube-controller-manager',
    }),
    kubeApiserverSelector: selectors.serializeHash(selector {
      job: 'apiserver',
    }),
    kubeProxySelector: selectors.serializeHash(selector {
      job: 'kube-proxy',
    }),
  },
};

separateMimirRecordingFiles(
  function(service, selector, extraArgs, _)
    {
      'kubernetes-mixin-rules': std.manifestYamlDoc({
        groups: std.filter(
          function(group)
            !std.startsWith(group.name, 'windows.')
            && group.name != 'kube-scheduler.rules',
          mixin(selector).prometheusRules.groups
        ),
      }),
    },
  serviceDefinition=kubeService
)
