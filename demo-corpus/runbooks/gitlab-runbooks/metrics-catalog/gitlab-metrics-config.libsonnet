local indexCatalog = import './index_catalog.libsonnet';
local aggregationSets = import './mimir-aggregation-sets.libsonnet';
local allSaturationTypes = import './saturation/all.libsonnet';
local allServices = import './services/all.jsonnet';
local allUtilizationMetrics = import './utilization/all.libsonnet';
local labelSet = import 'label-taxonomy/label-set.libsonnet';
local rawServiceCatalog = import 'raw-catalog.jsonnet';
local serviceCatalog = import 'service-catalog/service-catalog.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local overridenStageGroupMapping = import 'stage-group-mapping-with-overrides.jsonnet';
local objects = import 'utils/objects.libsonnet';
local strings = import 'utils/strings.libsonnet';

// Site-wide configuration options
{

  indexCatalog:: indexCatalog,

  // In accordance with Infra OKR: https://gitlab.com/gitlab-com/www-gitlab-com/-/issues/8024
  slaTarget:: 0.9995,

  // List of services with SLI/SLO monitoring
  monitoredServices:: allServices,

  // Hash of all aggregation sets
  aggregationSets:: aggregationSets,

  // dbPlatform: either a cloud service or "default"
  //  - `rds` - enables any RDS specific items
  //  - `default` - postgres installations on VM's
  dbPlatform:: 'default',

  // Hash of all saturation metric types that are monitored on gitlab.com
  saturationMonitoring:: objects.mergeAll(allSaturationTypes),

  // Hash of all utilization metric types that are monitored on gitlab.com
  utilizationMonitoring:: objects.mergeAll(allUtilizationMetrics),

  serviceCatalog:: rawServiceCatalog,

  keyServices::
    local keyServices = serviceCatalog.findKeyBusinessServices(includeZeroScore=true);
    std.map(function(service) service.name, keyServices),

  stageGroupMapping:: overridenStageGroupMapping,

  // stage-group-mapping-crossover.jsonnet is generated file, stored in the `services` directory
  stageGroupMappingCrossover:: import 'stage-group-mapping-crossover.jsonnet',

  // The base selector for the environment, as configured in Grafana dashboards
  grafanaEnvironmentSelector:: { environment: '$environment', env: '$environment' },

  // Signifies that a stage is partitioned into canary, main stage etc
  useEnvironmentStages:: true,

  // This metrics setup does use Thanos to create a global view
  usesThanos:: true,

  // Name of the default Prometheus datasource to use
  defaultPrometheusDatasource: mimirHelper.mimirDatasource('gitlab-gprd'),

  labelTaxonomy:: labelSet.makeLabelSet({
    environmentThanos: 'env',
    environment: 'environment',
    tier: 'tier',
    service: 'type',
    stage: 'stage',
    shard: 'shard',
    node: 'fqdn',
    sliComponent: 'component',
  }),

  // This allows separating global recording rules in Thanos.
  // The format is `name: selectorHash`.
  // For each entry in this object, we'll generate a separate recording rule file
  // for any definition in `thanos-rules-jsonnet/`
  // This allows us to decouple production recording rule evaluations
  // from non-production ones
  separateGlobalRecordingSelectors: {
    gprd: { env: 'gprd' },
    ops: { env: 'ops' },
    other: { env: { noneOf: ['gprd', 'ops'] } },
  },

  separateMimirRecordingSelectors: {
    'gitlab-gprd': {
      selector: { env: 'gprd' },
    },
    'gitlab-ops': {
      selector: { env: 'ops' },
    },
    'gitlab-gstg': {
      selector: { env: 'gstg' },
    },
    'gitlab-pre': {
      selector: { env: 'pre' },
    },
    metamonitoring: {
      selector: {},
    },
    'gitlab-observability': {
      selector: {},
    },
    runway: {
      selector: {},
    },
    'fulfillment-platform': {
      selector: {},
    },
    'analytics-eventsdot': {
      selector: {},
    },
  },

  gkeClustersByEnvironment: {
    gprd: [
      'gprd-gitlab-gke',
      'gprd-us-east1-b',
      'gprd-us-east1-c',
      'gprd-us-east1-d',
      'gitlab-3okls',  // dataplane v2 cluster
    ],
  },

  defaultMimirTenants: ['gitlab-gprd', 'gitlab-gstg'],
  mimirTenants:: std.objectFields(self.separateMimirRecordingSelectors),

  recordingRuleRegistry: import 'servicemetrics/recording-rule-registry/unified-registry.libsonnet',

  // This selector is used in a handful of places where there are too many "type" labels
  // and we want to exclude one (or more) labels
  baseSelector::
    {
      type: { ne: 'ops-gitlab-net' },
    },
}
