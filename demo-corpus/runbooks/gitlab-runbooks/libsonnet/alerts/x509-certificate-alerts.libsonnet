local alerts = import 'alerts/alerts.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local defaultSelector = {
};

local rules = function(selector=defaultSelector, tenant=null) {
  groups: [
    {
      name: 'X509 Certificate Alerts',
      rules: alerts.processAlertRules([
        {
          alert: 'X509ExporterReadErrors',
          expr: |||
            sum by (environment) (
              delta(x509_read_errors{%(selector)s}[15m])
            ) > 0
          ||| % {
            selector: selectors.serializeHash(selector),
          },
          'for': '5m',
          labels: {
            team: 'sre_reliability',
            severity: 's3',
            alert_type: 'cause',
          },
          annotations: {
            title: 'Increasing read errors for x509-certificate-exporter',
            description: |||
              Over the last 15 minutes, this x509-certificate-exporter instance
              has experienced errors reading certificate files or querying the
              Kubernetes API.

              This could be caused by a misconfiguration if triggered when the
              exporter starts.
            |||,
            grafana_datasource_id: tenant,
            runbook: 'certificates/',
          },
        },
        {
          alert: 'CertificateExpiration',
          expr: |||
            ((x509_cert_not_after{%(selector)s} - time()) / 86400) < 14
          ||| % {
            selector: selectors.serializeHash(selector),
          },
          'for': '15m',
          labels: {
            team: 'sre_reliability',
            severity: 's2',
            alert_type: 'cause',
            pager: 'pagerduty',
          },
          annotations: {
            title: 'Certificate is about to expire',
            description: |||
              Certificate for "{{ $labels.subject_CN }}" is about to expire
              {{if $labels.secret_name }}in Kubernetes secret "{{ $labels.secret_namespace }}/{{ $labels.secret_name }}" in cluster {{ $labels.cluster }}{{else}}at location "{{ $labels.filepath }}"{{end}}
            |||,
            grafana_datasource_id: tenant,
            runbook: 'certificates/',
          },
        },
        {
          alert: 'CertificateRenewal',
          expr: |||
            ((x509_cert_not_after{%(selector)s} - time()) / 86400) < 28
          ||| % {
            selector: selectors.serializeHash(selector),
          },
          'for': '15m',
          labels: {
            team: 'sre_reliability',
            severity: 's3',
            alert_type: 'cause',
          },
          annotations: {
            title: 'Certificate should be renewed',
            description: |||
              Certificate for "{{ $labels.subject_CN }}" should be renewed
              {{if $labels.secret_name }}in Kubernetes secret "{{ $labels.secret_namespace }}/{{ $labels.secret_name }}" in cluster {{ $labels.cluster }}{{else}}at location "{{ $labels.filepath }}"{{end}}
            |||,
            grafana_datasource_id: tenant,
            runbook: 'certificates/',
          },
        },
      ]),
    },
  ],
};

rules
