local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local customRateQuery = metricsCatalog.customRateQuery;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'topology-spanner',
  tier: 'db',
  team: 'cells_infrastructure',
  descriptiveName: 'Topology Service Cloud Spanner',

  tags: ['spanner', 'topology', 'cells'],

  monitoringThresholds: {
    // Liberal thresholds as placeholders for iteration
    apdexScore: 0.90,
    errorRatio: 0.90,
  },

  regional: false,  // Single managed GCP Spanner instance serves all regions

  provisioning: {
    vms: false,
    kubernetes: false,
  },

  serviceLevelIndicators: {
    spanner_api_latency: {
      userImpacting: true,
      featureCategory: 'not_owned',
      team: 'cells_infrastructure',
      severity: 's4',
      trafficCessationAlertConfig: false,

      description: |||
        Monitors Cloud Spanner API request latency for the Topology Service.
        Measures average latency per API method and instance.

        High latency could impact topology service performance and cause downstream issues.
      |||,

      requestRate: customRateQuery(|||
        sum by (%(aggregationLabels)s) (
          rate(
            stackdriver_spanner_instance_spanner_googleapis_com_api_request_latencies_per_transaction_options_count{
              job="runway-exporter",
              project_id="gitlab-runway-topo-svc-prod"
            }[%(burnRate)s]
          )
        )
      |||),

      // Calculate average latency in seconds
      latency: customRateQuery(|||
        sum by (%(aggregationLabels)s) (
          rate(
            stackdriver_spanner_instance_spanner_googleapis_com_api_request_latencies_per_transaction_options_sum{
              job="runway-exporter",
              project_id="gitlab-runway-topo-svc-prod"
            }[%(burnRate)s]
          )
        )
        /
        sum by (%(aggregationLabels)s) (
          rate(
            stackdriver_spanner_instance_spanner_googleapis_com_api_request_latencies_per_transaction_options_count{
              job="runway-exporter",
              project_id="gitlab-runway-topo-svc-prod"
            }[%(burnRate)s]
          )
        )
      |||),

      significantLabels: ['method', 'instance_id'],

      toolingLinks: [],
    },

    spanner_api_errors: {
      userImpacting: true,
      featureCategory: 'not_owned',
      team: 'cells_infrastructure',
      severity: 's4',
      trafficCessationAlertConfig: false,

      description: |||
        Monitors Cloud Spanner API request errors for the Topology Service.
        Tracks requests that return non-OK status codes.

        High error rates indicate problems with Spanner connectivity or query issues.
      |||,

      requestRate: customRateQuery(|||
        sum by (%(aggregationLabels)s) (
          rate(
            stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{
              job="runway-exporter",
              project_id="gitlab-runway-topo-svc-prod"
            }[%(burnRate)s]
          )
        )
      |||),

      errorRate: customRateQuery(|||
        sum by (%(aggregationLabels)s) (
          rate(
            stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{
              job="runway-exporter",
              project_id="gitlab-runway-topo-svc-prod",
              status!="OK"
            }[%(burnRate)s]
          )
        )
      |||),

      significantLabels: ['method', 'status', 'instance_id'],

      toolingLinks: [
        toolingLinks.stackdriverLogs(
          'Cloud Spanner Logs',
          queryHash={
            'resource.type': 'spanner_instance',
            'resource.labels.project_id': 'gitlab-runway-topo-svc-prod',
          },
        ),
      ],
    },

    spanner_api_requests: {
      userImpacting: true,
      featureCategory: 'not_owned',
      team: 'cells_infrastructure',
      severity: 's4',
      trafficCessationAlertConfig: false,

      description: |||
        Monitors total Cloud Spanner API request volume for the Topology Service.
        Tracks all API requests by method and instance.

        Useful for capacity planning and identifying usage patterns.
      |||,

      requestRate: customRateQuery(|||
        sum by (%(aggregationLabels)s) (
          rate(
            stackdriver_spanner_instance_spanner_googleapis_com_api_request_count{
              job="runway-exporter",
              project_id="gitlab-runway-topo-svc-prod"
            }[%(burnRate)s]
          )
        )
      |||),

      significantLabels: ['method', 'instance_id'],

      toolingLinks: [],
    },
  },

  skippedMaturityCriteria: {
    'Structured logs available in Kibana': 'Cloud Spanner is a managed service of GCP. The logs are available in Stackdriver.',
    'Developer guides exist in developer documentation': 'Cloud Spanner is an infrastructure component, powered by GCP',
    'Service exists in the dependency graph': 'Cloud Spanner is a managed GCP database service. Topology service applications depend on it, but the reverse is not true.',
  },
})
