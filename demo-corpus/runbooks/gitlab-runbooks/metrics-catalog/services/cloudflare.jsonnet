local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;

metricsCatalog.serviceDefinition({
  type: 'cloudflare',
  tier: 'lb',
  tenants: ['gitlab-ops', 'gitlab-gprd', 'gitlab-gstg'],
  monitoringThresholds: {
    // Monitoring data may be unreliable.
    // See: https://gitlab.com/gitlab-com/gl-infra/production/-/issues/5465
    errorRatio: 0.99,
  },
  serviceDependencies: {
    frontend: true,
    nat: true,
  },
  provisioning: {
    kubernetes: false,
    vms: false,
  },

  // No stages for Thanos
  serviceIsStageless: true,

  serviceLevelIndicators: {
    gitlab_zone: {
      severity: 's3',
      team: 'networking_and_incident_management',
      userImpacting: true,  // Low until CF exporter metric quality increases https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/10294
      featureCategory: 'not_owned',
      description: |||
        Aggregation of all public traffic for GitLab.com passing through Cloudflare.

        Errors on this SLI may indicate serious upstream failures on GitLab.com.
        They could also indicate connectivity issues between Cloudflare and the origin.
        See https://developers.cloudflare.com/support/troubleshooting/cloudflare-errors/troubleshooting-cloudflare-5xx-errors/
        for more information.
      |||,

      local zoneSelector = { zone: { re: 'gitlab.com|staging.gitlab.com' } },
      requestRate: rateMetric(
        counter='cloudflare_zone_requests_total',
        selector=zoneSelector
      ),

      errorRate: rateMetric(
        counter='cloudflare_zone_requests_status',
        selector=zoneSelector {
          status: { re: '5..' },
        },
      ),

      significantLabels: [],
    },
    // The "gitlab.net" zone
    gitlab_net_zone: {
      severity: 's3',
      team: 'networking_and_incident_management',
      userImpacting: false,  // Low until CF exporter metric quality increases https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/10294
      featureCategory: 'not_owned',
      description: |||
        Aggregation of all GitLab.net (non-pulic) traffic passing through Cloudflare.

        Errors on this SLI may indicate serious upstream failures on GitLab.net.
        They could also indicate connectivity issues between Cloudflare and the origin.
        See https://developers.cloudflare.com/support/troubleshooting/cloudflare-errors/troubleshooting-cloudflare-5xx-errors/
        for more information.
      |||,

      local zoneSelector = { zone: 'gitlab.net' },

      requestRate: rateMetric(
        counter='cloudflare_zone_requests_total',
        selector=zoneSelector
      ),

      errorRate: rateMetric(
        counter='cloudflare_zone_requests_status',
        selector=zoneSelector {
          status: { re: '5..' },
        },
      ),

      significantLabels: [],
    },
    cloud_gitlab_zone: {
      severity: 's3',
      team: 'runway',
      userImpacting: true,  // Low until CF exporter metric quality increases https://gitlab.com/gitlab-com/gl-infra/reliability/-/issues/10294
      featureCategory: 'not_owned',
      description: |||
        Aggregation of all public traffic for cloud.gitlab.com passing through Cloudflare.

        Errors on this SLI most likely indicate upstream failures in GitLab-operated backends.
        They could also indicate connectivity issues between Cloudflare and the origin.
        See https://developers.cloudflare.com/support/troubleshooting/cloudflare-errors/troubleshooting-cloudflare-5xx-errors/
        for more information.
      |||,

      local zoneSelector = { zone: { re: 'cloud.gitlab.com|cloud.staging.gitlab.com' } },
      requestRate: rateMetric(
        counter='cloudflare_zone_requests_total',
        selector=zoneSelector
      ),

      errorRate: rateMetric(
        counter='cloudflare_zone_requests_status',
        selector=zoneSelector {
          status: [
            { re: '5..' },
            { ne: '502' },
          ],
        },
      ),

      significantLabels: [],
    },

  },
  skippedMaturityCriteria: {
    'Developer guides exist in developer documentation': 'WAF is an infrastructure component, powered by Cloudflare',
    'Structured logs available in Kibana': 'Logs from CloudFlare are pushed to a GCS bucket by CloudFlare, and not ingested to ElasticSearch due to volume.  See https://runbooks.gitlab.com//cloudflare/logging/ for alternatives',
  },
})
