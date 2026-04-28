local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local kubeLabelSelectors = metricsCatalog.kubeLabelSelectors;
local rateMetric = metricsCatalog.rateMetric;

// See https://www.vaultproject.io/docs/internals/telemetry for more details about Vault metrics

metricsCatalog.serviceDefinition({
  type: 'vault',
  tier: 'inf',
  tenants: ['gitlab-ops', 'gitlab-pre'],

  tags: ['golang'],

  serviceIsStageless: true,

  monitoringThresholds: {
    apdexScore: 0.999,
    errorRatio: 0.999,
  },

  provisioning: {
    kubernetes: true,
    vms: false,
  },

  kubeConfig: {
    local kubeSelector = { namespace: 'vault' },

    labelSelectors: kubeLabelSelectors(
      nodeSelector={ type: 'vault' }
    ),
  },

  kubeResources: {
    vault: {
      kind: 'StatefulSet',
      containers: [
        'vault',
      ],
    },
  },

  serviceLevelIndicators: {
    istio_public_ingress: {
      userImpacting: true,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      local selector = {
        source_workload: 'istio-gateway',
        destination_workload: 'vault',
      },

      apdex: histogramApdex(
        histogram='istio_request_duration_milliseconds_bucket',
        selector=selector,
        satisfiedThreshold=1000.0,
      ),

      requestRate: rateMetric(
        counter='istio_requests_total',
        selector=selector
      ),

      errorRate: rateMetric(
        counter='istio_requests_total',
        selector=selector {
          response_code: { re: '^5.*' },
        }
      ),
      emittedBy: [],  // TODO: Add type label in the source metrics https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2873

      significantLabels: ['destination_service', 'response_code'],
    },

    istio_internal_ingress: {
      userImpacting: true,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      local selector = {
        source_workload: 'istio-internal-gateway',
        destination_workload: 'vault',
      },

      apdex: histogramApdex(
        histogram='istio_request_duration_milliseconds_bucket',
        selector=selector,
        satisfiedThreshold=1000.0,
      ),

      requestRate: rateMetric(
        counter='istio_requests_total',
        selector=selector
      ),

      errorRate: rateMetric(
        counter='istio_requests_total',
        selector=selector {
          response_code: { re: '^5.*' },
        }
      ),

      emittedBy: [],  // TODO: Add type label in the source metrics https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2873

      significantLabels: ['destination_service', 'response_code'],
    },

    vault: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        Hashicorp Vault is a secret management service that provides secrets for Kubernetes and provisioning pipelines.
        This SLI monitors the Vault HTTP interface. 5xx responses are considered failures.
      |||,

      local vaultSelector = {
        job: 'vault-active',
      },

      requestRate: rateMetric(
        counter='vault_core_handle_request_count',
        selector=vaultSelector,
      ),
      emittedBy: [],  // TODO: Add type label in the source metrics https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2873

      significantLabels: ['pod'],
    },

    vault_audit_log_request: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        Vault failed to make an audit log request to any of the configured
        audit log devices, ceasing all user operations.
      |||,

      local vaultSelector = {
        job: 'vault-active',
      },

      requestRate: rateMetric(
        counter='vault_audit_log_request_count',
        selector=vaultSelector
      ),

      errorRate: rateMetric(
        counter='vault_audit_log_request_failure',
        selector=vaultSelector,
      ),
      emittedBy: [],  // TODO: Add type label in the source metrics https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2873

      significantLabels: ['pod'],
    },

    vault_audit_log_response: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: false,

      description: |||
        Vault failed to make an audit log responses to any of the configured
        audit log devices, ceasing all user operations.
      |||,

      local vaultSelector = {
        job: 'vault-active',
      },

      requestRate: rateMetric(
        counter='vault_audit_log_response_count',
        selector=vaultSelector
      ),

      errorRate: rateMetric(
        counter='vault_audit_log_response_failure',
        selector=vaultSelector,
      ),
      emittedBy: [],  // TODO: Add type label in the source metrics https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/2873

      significantLabels: ['pod'],
    },
  },
  skippedMaturityCriteria: {
    'Structured logs available in Kibana': "Vault is a pending project at the moment. There is no traffic at the moment. We'll add logs and metrics in https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/739",
    'Service exists in the dependency graph': 'Vault is a pending project at the moment. There is no traffic at the moment. The progress can be tracked at https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/739',
    'Developer guides exist in developer documentation': 'Vault is an infrastructure component, developers do not interact with it',
  },
})
