local recordingRules = import 'kube-state-metrics/recording-rules.libsonnet';
local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;

local filesForSeparateSelector(service, selector, extraArgs, _) =
  local groups = recordingRules.groupsWithFilter(
    function(s) !s.dangerouslyThanosEvaluated && s.type == service.type,
    selector
  );
  {
    [if std.length(groups) > 0 then 'kube-state-metrics']: std.manifestYamlDoc({ groups: groups }),
  };

std.foldl(
  function(memo, service)
    memo + separateMimirRecordingFiles(filesForSeparateSelector, service),
  recordingRules.kubeServices,
  {}
)
