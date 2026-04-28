local rules = import 'recording-rules/stage-group-monthly-availability.libsonnet';

// This is filtered to only record for gprd, no need to separatly record for each environment
{
  'gitlab-gprd/stage-group-monthly-availability.yml': std.manifestYamlDoc(rules()),
}
