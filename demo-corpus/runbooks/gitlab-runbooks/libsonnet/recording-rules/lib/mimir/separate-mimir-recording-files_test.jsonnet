local separateMimirRecordingFiles = (import './separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local test = import 'test.libsonnet';
local serviceDefinition = import 'servicemetrics/service_definition.libsonnet';
local metricsConfig = (import 'gitlab-metrics-config.libsonnet');

local fakeService = serviceDefinition.serviceDefinition({
  type: 'foo',
  tenants: ['gitlab-ops', 'gitlab-gprd', 'gitlab-pre'],
});

test.suite({
  testSeparateMimirRecordingFiles: {
    actual: separateMimirRecordingFiles(
      function(service, selector, extraArgs, _) { rule_file_basename: selector },
      serviceDefinition=fakeService,
      metricsConfig=metricsConfig
    ),
    expect: {
      'gitlab-ops/foo/gitlab-ops-foo-rule_file_basename.yml': { env: 'ops' },
      'gitlab-gprd/foo/gitlab-gprd-foo-rule_file_basename.yml': { env: 'gprd' },
      'gitlab-pre/foo/gitlab-pre-foo-rule_file_basename.yml': { env: 'pre' },
    },
  },
  testSeparateMimirRecordingFilesWithoutService: {
    actual: separateMimirRecordingFiles(
      function(service, selector, extraArgs, _) { rule_file_basename: selector },
      metricsConfig=metricsConfig
    ),
    expect: {
      'gitlab-gprd/gitlab-gprd-rule_file_basename.yml': { env: 'gprd' },
      'gitlab-gstg/gitlab-gstg-rule_file_basename.yml': { env: 'gstg' },
    },
  },
})
