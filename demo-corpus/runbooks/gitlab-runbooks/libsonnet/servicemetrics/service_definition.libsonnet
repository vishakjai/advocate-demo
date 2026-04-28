local config = import 'gitlab-metrics-config.libsonnet';
local kubeLabelSelectors = import 'kube_label_selectors.libsonnet';
local multiburnExpression = import 'mwmbr/expression.libsonnet';
local maturityLevels = import 'service-maturity/levels.libsonnet';
local serviceLevelIndicatorDefinition = import 'service_level_indicator_definition.libsonnet';
local misc = import 'utils/misc.libsonnet';
local objects = import 'utils/objects.libsonnet';
local validator = import 'utils/validator.libsonnet';
local capacityPlanning = (import 'capacity-planning/validator.libsonnet');

local serviceDefinitionValidator = validator.new(
  {
    shards: validator.optional(validator.arrayOfStrings),
    defaultToolingLinks: validator.optional(validator.array),
    team: validator.or(
      validator.validator(function(v) v == null, 'is not null'),
      validator.setMember(std.set(std.map(function(team) team.name, config.serviceCatalog.teams))),
    ),
  }
  + capacityPlanning
);

// For now we assume that services are provisioned on vms and not kubernetes
local provisioningDefaults = { vms: true, kubernetes: false, runway: false };
local serviceDefaults = {
  team: null,
  tags: [],
  serviceIsStageless: false,  // Set to true for services that don't use stage labels
  autogenerateRecordingRules: true,
  disableOpsRatePrediction: false,
  nodeLevelMonitoring: false,  // By default we do not use node-level monitoring
  monitoring: {
    shard: {
      enabled: false,
      overrides: {},  // To override shard-level SLO for specific shards
    },
    node: {
      enabled: false,
      thresholds: {},  // To set node level SLO thresholds
      overrides: {},  // To override node-level SLO for specific nodes
    },
  },
  kubeConfig: {},
  kubeResources: {},
  regional: false,  // By default we don't support regional monitoring for services
  alertWindows: multiburnExpression.defaultWindows,
  skippedMaturityCriteria: {},
  dangerouslyThanosEvaluated: false,  // This is only used for thanos self-monitoring
  capacityPlanning: {},  // Consumed by Tamland
  tenants: std.get(config, 'defaultMimirTenants', []),  // List of Mimir tenants in which the recording rules are generated
  defaultTenant: if std.length(self.tenants) > 0 then self.tenants[0],  // Default tenant for dashboard datasource, saturation manifest
  useConfidenceLevelForSLIAlerts: null,  // Use confidence interval default values across all SLIs in a service
  defaultToolingLinks: [],  // Fallback links for SLIs that do not define toolingLinks
};

local shardLevelMonitoringEnabled(serviceDefinition) =
  misc.dig(serviceDefinition, ['monitoring', 'shard', 'enabled']) == true;

local validateMonitoring(serviceDefinition) =
  local shardLevelSlis = [
    sli.key
    for sli in std.objectKeysValues(serviceDefinition.serviceLevelIndicators)
    if sli.value.shardLevelMonitoring
  ];
  local validateShardOverrides(obj) =
    if std.length(obj) == 0 then
      true
    else
      misc.arrayDiff(std.objectFields(obj), shardLevelSlis) == [];

  local monitoringValidator = validator.new({
    monitoring: {
      shard: {
        enabled: validator.boolean,
        overrides: validator.validator(
          validateShardOverrides,
          'SLI must be present and has shardLevelMonitoring enabled. Supported SLIs: %s' % std.join(', ', shardLevelSlis)
        ),
      },
      node: {
        enabled: validator.boolean,
        thresholds: validator.object,
        overrides: validator.object,
      },
    },
  });

  monitoringValidator.assertValid(serviceDefinition);

local validateTenants(serviceDefinition) =
  local mimirTenants = config.mimirTenants;
  local tenantMemberValidator = validator.validator(
    function(v) misc.arrayDiff(v, mimirTenants) == [],
    'Invalid tenants in %s service. Allowed tenants: %s' % [serviceDefinition.type, mimirTenants]
  );
  local tenantsValidator = validator.new({
    tenants: validator.and(
      validator.arrayOfStrings,
      tenantMemberValidator
    ),
    defaultTenant: validator.optional(validator.setMember(mimirTenants)),
    tenantEnvironmentTargets: validator.optional(validator.arrayOfStrings),
  });

  tenantsValidator.assertValid(serviceDefinition);

local validate(serviceDefinition) =
  validateTenants(serviceDefinition)
  +
  validateMonitoring(serviceDefinition)
  +
  serviceDefinitionValidator.assertValid(serviceDefinition);

// Convenience method, will wrap a raw definition in a serviceLevelIndicatorDefinition if needed
local prepareComponent(definition) =
  if std.objectHasAll(definition, 'initServiceLevelIndicatorWithName') then
    // Already prepared
    definition
  else
    // Wrap class as a component definition
    serviceLevelIndicatorDefinition.serviceLevelIndicatorDefinition(definition);

local validateAndApplyServiceDefaults(service) =
  local serviceWithMonitoringDefaults =
    service { monitoring: objects.nestedMerge(serviceDefaults.monitoring, std.get(service, 'monitoring', default={})) };

  local serviceWithProvisioningDefaults =
    objects.nestedMerge(
      serviceDefaults { provisioning: provisioningDefaults }, serviceWithMonitoringDefaults
    );

  local serviceWithDefaults = if serviceWithProvisioningDefaults.provisioning.kubernetes then
    local labelSelectors = if std.objectHas(serviceWithProvisioningDefaults.kubeConfig, 'labelSelectors') then
      serviceWithProvisioningDefaults.kubeConfig.labelSelectors
    else
      // Setup a default set of node selectors, based on the `type` label
      kubeLabelSelectors();

    local labelSelectorsInitialized = labelSelectors.init(type=serviceWithProvisioningDefaults.type, tier=serviceWithProvisioningDefaults.tier);
    serviceWithProvisioningDefaults + ({ kubeConfig+: { labelSelectors: labelSelectorsInitialized } })
  else
    serviceWithProvisioningDefaults;

  local sliInheritedDefaults =
    {
      regional: serviceWithDefaults.regional,
      type: serviceWithDefaults.type,
      // Team will be the default team that alerts will be routed to for this service.
      // This can be overriden per SLI. See the README.md for details.
      team: serviceWithDefaults.team,
      useConfidenceLevelForSLIAlerts: serviceWithDefaults.useConfidenceLevelForSLIAlerts,
      defaultToolingLinks: serviceWithDefaults.defaultToolingLinks,
    }
    +
    (
      // When stage labels are disabled, we default all SLI recording rules
      // to the main stage
      if serviceWithDefaults.serviceIsStageless then
        { staticLabels+: { stage: 'main' } }
      else
        {}
    )
    +
    (
      if std.objectHas(serviceWithDefaults, 'monitoringThresholds') then
        { monitoringThresholds: serviceWithDefaults.monitoringThresholds }
      else
        {}
    )
    +
    (
      if shardLevelMonitoringEnabled(serviceWithDefaults) then
        { shardLevelMonitoring: true }
      else
        {}
    );

  // If this service is provisioned on kubernetes we should include a kubernetes deployment map
  validate(serviceWithDefaults {
    tags: std.set(serviceWithDefaults.tags),
    serviceLevelIndicators: {
      [sliName]: prepareComponent(service.serviceLevelIndicators[sliName]).initServiceLevelIndicatorWithName(sliName, sliInheritedDefaults)
      for sliName in std.objectFields(service.serviceLevelIndicators)
    },
    skippedMaturityCriteria: maturityLevels.skip(
      if std.objectHas(service, 'contractualThresholds') then
        serviceWithDefaults.skippedMaturityCriteria
      else
        serviceWithDefaults.skippedMaturityCriteria + ({ 'SLA calculations driven from SLO metrics': 'Service is not user facing' })
    ),
  });

local serviceDefinition(service) =
  // Private functions
  local private = {
    serviceHasComponentWith(keymetricName)::
      std.foldl(
        function(memo, sliName) memo || std.objectHas(service.serviceLevelIndicators[sliName], keymetricName),
        std.objectFields(service.serviceLevelIndicators),
        false
      ),
    serviceHasComponentWithFeatureCategory()::
      std.foldl(
        function(memo, sliName) memo || service.serviceLevelIndicators[sliName].hasFeatureCategory(),
        std.objectFields(service.serviceLevelIndicators),
        false
      ),
  };

  service {
    hasApdex():: private.serviceHasComponentWith('apdex'),
    hasRequestRate():: std.length(std.objectFields(service.serviceLevelIndicators)) > 0,
    hasErrorRate():: private.serviceHasComponentWith('errorRate'),
    hasFeatureCategorySLIs():: private.serviceHasComponentWithFeatureCategory(),

    getProvisioning()::
      service.provisioning,

    // Returns an array of serviceLevelIndicators for this service
    listServiceLevelIndicators()::
      [
        service.serviceLevelIndicators[sliName]
        for sliName in std.objectFields(service.serviceLevelIndicators)
      ],

    // Returns true if this service has a
    // dedicated node pool
    hasDedicatedKubeNodePool()::
      service.provisioning.kubernetes &&
      service.kubeConfig.labelSelectors.hasNodeSelector(),

    isShardLevelMonitored():: shardLevelMonitoringEnabled(service),
    getShardMonitoringOverrides():: misc.dig(service, ['monitoring', 'shard', 'overrides']),

    // Returns true if the SLI has shardLevelMonitoring enabled and
    // specified in `monitoring.shard.overrides`
    hasShardMonitoringOverrides(sli)::
      sli.shardLevelMonitoring &&
      std.objectHas(self.getShardMonitoringOverrides(), sli.name),

    // Returns an array of { shard: shardName, threshold: thresholdField }
    // for each shard with overriden SLI for the given thresholdField.
    // Example: [ { name: 'urgent-other', threshold: 0.97 } ]
    listOverridenShardsMonitoringThresholds(sli, thresholdField)::
      std.filter(
        function(shardWithThreshold) std.isNumber(shardWithThreshold.threshold),
        std.map(
          function(shard)
            {
              shard: shard.key,
              threshold: std.get(shard.value, thresholdField),
            },
          std.objectKeysValues(std.get(
            self.getShardMonitoringOverrides(),
            sli.name,
            default={}
          ))
        )
      ),
  };

{
  serviceDefinition(service)::
    serviceDefinition(validateAndApplyServiceDefaults(service)),
}
