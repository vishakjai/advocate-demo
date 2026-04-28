local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local recordingRuleRegistry = import 'servicemetrics/recording-rule-registry.libsonnet';
local sidekiqQueueRules = import 'recording-rules/sidekiq-queue-rules.libsonnet';

local rules(extraSelector) = {
  groups: [{
    name: 'Sidekiq Aggregated Alerts',
    interval: '1m',
    rules: sidekiqQueueRules.sidekiqPerWorkerAlertRules(recordingRuleRegistry.unifiedRegistry, extraSelector),
  }],
};

separateMimirRecordingFiles(
  function(service, selector, extraArgs, _)
    {
      'sidekiq-alerts': std.manifestYamlDoc(rules(selector)),
    }
)
