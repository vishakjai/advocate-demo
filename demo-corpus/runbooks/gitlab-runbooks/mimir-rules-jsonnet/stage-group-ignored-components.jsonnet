local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local ignoredComponentRuleGroup = import 'recording-rules/stage-group-ignored-components.libsonnet';

local outputPromYaml(groups) =
  std.manifestYamlDoc({
    groups: groups,
  });

// The ignored components are the same for a group across environments.
// No need to separate this by environment

separateMimirRecordingFiles(
  function(service, selector, extraArgs, _)
    {
      'stage-group-ignored-components': outputPromYaml(ignoredComponentRuleGroup),
    }
)
