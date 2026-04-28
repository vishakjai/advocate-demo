local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

{
  nat_gateway_port_allocation: resourceSaturationPoint({
    title: 'Cloud NAT Gateway Port Allocation',
    severity: 's2',

    // Technically, this is horizontally scalable, but requires us to send out
    // adequate notice to our customers before scaling it up, eg
    // https://gitlab.com/gitlab-org/gitlab/-/merge_requests/37444 and
    // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/3991 for examples
    horizontallyScalable: false,

    staticLabels: {
      type: 'nat',
      tier: 'inf',
      stage: 'main',
    },
    appliesTo: ['nat', 'runway'],
    description: |||
      Each NAT IP address on a Cloud NAT gateway offers 64,512 TCP source ports and 64,512 UDP source ports.

      When these are exhausted, processes may experience connection problems to external destinations. In the application these
      may manifest as SMTP connection drops or webhook delivery failures. In Kubernetes, nodes may fail while
      attempting to download images from external repositories.

      This rule covers both core GitLab NAT gateways (gitlab-production, gitlab-staging-1) and Runway NAT
      gateways (gitlab-runway-production, gitlab-runway-staging).

      More details in the Cloud NAT documentation: https://cloud.google.com/nat/docs/ports-and-addresses
    |||,

    grafana_dashboard_uid: 'sat_nat_gw_port_allocation',
    resourceLabels: ['gateway_name', 'project_id'],
    burnRatePeriod: '5m',  // This needs to be high, since the StackDriver export only updates infrequently
    query: |||
      sum without(nat_ip) (
        stackdriver_nat_gateway_router_googleapis_com_nat_allocated_ports{%(selectorWithoutType)s}
      )
      /
      on(router_id, gateway_name, region, project_id) group_left
      gcp_cloud_nat_ports_capacity_total
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
}
