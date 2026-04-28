local config = import 'gitlab-metrics-config.libsonnet';
local validator = import 'utils/validator.libsonnet';

local defaults = {
  type: 'instant',
  tenantId: 'gitlab-gprd',
};

// Supported query types should be defined here with their params
// See https://prometheus.io/docs/prometheus/latest/querying/api
// Adding a new type would also require adding the path in the `PrometheusApi` in
// lib/periodic_queries/prometheus_api.rb
local paramsPerType = {
  // https://prometheus.io/docs/prometheus/latest/querying/api/#instant-queries
  instant: ['query', 'time', 'timeout'],
};

local validateRequestParams(definition) =
  local supportedFields = paramsPerType[definition.type];

  local v = validator.new({
    requestParams: validator.validator(
      function(object)
        local definedFields = std.objectFields(object);
        std.setDiff(definedFields, supportedFields) == []
      , 'Only [%(fields)s] are supported for %(type)s queries' % {
        fields: std.join(', ', supportedFields),
        type: definition.type,
      }
    ),
  });
  v.assertValid(definition);

local validateQuery(definition) =
  local v = validator.new({
    // Currently only instant queries are supported
    type: validator.setMember(std.objectFields(paramsPerType)),
    // all fields in requestParams is passed on as request params when querying Prometheus
    requestParams: validator.object,
    tenantId: validator.setMember(config.mimirTenants),
  });
  v.assertValid(definition);

local validate(definition) =
  validateQuery(definition) + validateRequestParams(definition);

local validateAndApplyDefaults(definition) =
  local definitionWithDefaults = defaults + definition;
  validate(definitionWithDefaults);

{
  new(definition):: validateAndApplyDefaults(definition),
}
