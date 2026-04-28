local googleLoadBalancerComponents = import './lib/google_load_balancer_components.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

local gaugeMetric = metricsCatalog.gaugeMetric;

metricsCatalog.serviceDefinition({
  type: 'packagecloud',
  tier: 'inf',
  tenants: ['gitlab-ops', 'gitlab-pre'],

  tags: ['cloud-sql'],

  serviceIsStageless: true,

  provisioning: {
    kubernetes: true,
    vms: false,
  },

  monitoringThresholds: {
    errorRatio: 0.999,
  },

  regional: false,

  serviceDependencies: {
    'cloud-sql': true,
    kube: true,
    memorystore: true,
  },

  kubeConfig: {},
  kubeResources: {
    rainbows: {
      kind: 'Deployment',
      containers: [
        'packagecloud',
        'memorystore-tls',
      ],
    },
    resque: {
      kind: 'Deployment',
      containers: [
        'packagecloud',
        'memorystore-tls',
      ],
    },
    web: {
      kind: 'Deployment',
      containers: [
        'packagecloud',
        'memorystore-tls',
      ],
    },
    toolbox: {
      kind: 'Deployment',
      containers: [
        'packagecloud',
        'memorystore-tls',
      ],
    },
    'sql-proxy': {
      kind: 'Deployment',
      containers: [
        'sqlproxy',
      ],
    },
  },

  local sliCommon = {
    userImpacting: true,
    team: 'reliability_unowned',
    severity: 's4',
  },

  serviceLevelIndicators: {
    loadbalancer: googleLoadBalancerComponents.googleLoadBalancer(
      userImpacting=sliCommon.userImpacting,
      loadBalancerName={ re: 'k8s2-.+-packagecloud-packagecloud-.+' },
      projectId={ re: 'gitlab-(ops|pre)' },
      additionalToolingLinks=[
        toolingLinks.kibana(title='Packagecloud (prod)', index='packagecloud'),
        toolingLinks.googleLoadBalancer(instanceId='k8s2-um-4zodnh0s-packagecloud-packagecloud-xnkztiio', project='gitlab-ops', titleSuffix=' (prod)'),
        toolingLinks.aesthetics.separator(),
        toolingLinks.kibana(title='Packagecloud (nonprod)', index='packagecloud_pre'),
        toolingLinks.googleLoadBalancer(instanceId='k8s2-um-spdr6cwv-packagecloud-packagecloud-cco5unyp', project='gitlab-pre', titleSuffix=' (nonprod)'),
      ],
      extra=sliCommon,
    ),
    cloudsql: sliCommon {
      description: |||
        Packagecloud uses a GCP CloudSQL MySQL instance. This SLI represents SQL queries executed by the server.
      |||,

      requestRate: gaugeMetric(
        gauge='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_mysql_queries',
        selector={
          database_id: { re: '.+:packagecloud-.+' },
        }
      ),
      significantLabels: ['database_id'],
      serviceAggregation: false,  // Don't include cloudsql in the aggregated RPS for the service
      toolingLinks: [
        toolingLinks.cloudSQL('packagecloud-f05c90f5', 'gitlab-ops'),
      ],
      // This is based on stackdriver metrics, that are labeled with the `type='monitoring'
      emittedBy: ['monitoring'],
    },
  },
})
