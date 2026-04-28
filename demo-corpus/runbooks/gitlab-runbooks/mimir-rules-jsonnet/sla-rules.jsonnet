local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local rules = import 'recording-rules/sla-rules.libsonnet';

local fileForService(service, selector, _extraArgs, _) =
  {
    'occurrence-sla-availability': std.manifestYamlDoc(
      rules.occurrenceRateSlaRules(selector { type: service.type })
    ),
  };

separateMimirRecordingFiles(
  function(_, selector, _, _)
    {
      'sla-rules': std.manifestYamlDoc(
        rules.weightedTimeAverageSlaRules(
          selector,
          sloObservationStatusMetric='slo:observation_status',
        )
      ),
    } + {
      // The SLA is the same for all environments, no need to have separate files
      'sla-target': std.manifestYamlDoc(
        rules.slaTargetRules()
      ),
    }
)
+ std.foldl(
  function(memo, service)
    memo + separateMimirRecordingFiles(fileForService, service),
  (import 'gitlab-metrics-config.libsonnet').monitoredServices,
  {}
)
