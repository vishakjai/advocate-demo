local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;
local selectors = import 'promql/selectors.libsonnet';

{
  gcp_quota_limit: resourceSaturationPoint({
    title: 'GCP Quota utilization per environment',
    severity: 's2',
    horizontallyScalable: false,
    appliesTo: ['monitoring'],
    burnRatePeriod: '5m',
    runbook: 'uncategorized/alerts/gcp_quota_limit/',
    description: |||
      GCP Quota utilization / limit ratio

      Saturation on a quota may cause problems with creating infrastructure resources on GCP.

      To fix, we can request a quota increase for the specific resource to the GCP support team.
    |||,
    grafana_dashboard_uid: 'gcp_quota_limit',
    resourceLabels: ['project', 'metric', 'quotaregion', 'region'],
    useResourceLabelsAsMaxAggregationLabels: true,
    query: |||
      (
        gcp_quota_usage{%(selector)s}
      /
        gcp_quota_limit{%(selector)s}
      ) > 0
    |||,
    slos: {
      soft: 0.85,
      hard: 0.90,
      alertTriggerDuration: '15m',
    },
    capacityPlanning: {
      saturation_dimensions: [
        { selector: selectors.serializeHash({ region: 'us-central1' }) },
        { selector: selectors.serializeHash({ region: 'us-east1' }) },
        { selector: selectors.serializeHash({ region: 'us-east4' }) },
      ],
    },
  }),

  gcp_quota_limit_service_account_token_creation: resourceSaturationPoint(self.gcp_quota_limit {
    severity: 's2',
    grafana_dashboard_uid: 'sat_gcp_quota_sa_token_creation',
    resourceLabels: ['project_id'],
    description: |||
      GCP Quota utilization / limit ratio for credentials generation requests per minute per project.

      Saturation on the quota may cause problems with signing storage object URLs in Workload-Identity enabled Kubernetes workloads, which would result in failures from artifact fetch requests.

      To fix, we can request a quota increase for "Generate credentials request per minute" to the GCP support team.
    |||,
    query: |||
      (
        sum by (project_id) (stackdriver_consumer_quota_serviceruntime_googleapis_com_quota_rate_net_usage{quota_metric="iamcredentials.googleapis.com/service_account_token_creation",%(selector)s})
        /
        sum by (project_id) (stackdriver_consumer_quota_serviceruntime_googleapis_com_quota_limit{quota_metric="iamcredentials.googleapis.com/service_account_token_creation",%(selector)s})
      ) > 0
    |||,
    capacityPlanning: {
      saturation_dimensions: [],
    },
  }),
}
