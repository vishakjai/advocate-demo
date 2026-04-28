local separateGlobalRecordingFiles = (import './separate-global-recording-files.libsonnet').separateGlobalRecordingFiles;
local test = import 'test.libsonnet';

local fakeMetricsConfig = {
  separateGlobalRecordingSelectors: {
    ops: { env: 'ops' },
    gprd: { env: 'gprd' },
  },
};

test.suite({
  testSeparateGlobalRecordingFiles: {
    actual: separateGlobalRecordingFiles(
      function(selector)
        { hello: selector },
      fakeMetricsConfig
    ),
    expect: {
      'hello-ops.yml': { env: 'ops' },
      'hello-gprd.yml': { env: 'gprd' },
    },
  },
})
