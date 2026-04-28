local gitlabMetricsConfig = import 'gitlab-metrics-config.libsonnet';
{
  selectiveRegistry:: import './recording-rule-registry/selective-registry.libsonnet',
  unifiedRegistry:: import './recording-rule-registry/unified-registry.libsonnet',
  nullRegistry:: import './recording-rule-registry/null-registry.libsonnet',
  defaultConfig:: {
    recordingRuleRegistry: gitlabMetricsConfig.recordingRuleRegistry,
  },
}
