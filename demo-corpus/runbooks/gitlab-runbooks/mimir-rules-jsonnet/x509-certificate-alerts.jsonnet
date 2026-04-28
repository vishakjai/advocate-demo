local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local x509CertificateAlerts = import 'alerts/x509-certificate-alerts.libsonnet';

separateMimirRecordingFiles(
  function(service, selector, extraArgs, tenant)
    {
      'x509-certificate-alerts': std.manifestYamlDoc(x509CertificateAlerts(selector, tenant)),
    }
)
