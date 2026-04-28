local separateMimirRecordingFiles = (import 'recording-rules/lib/mimir/separate-mimir-recording-files.libsonnet').separateMimirRecordingFiles;
local monitoredServices = (import 'gitlab-metrics-config.libsonnet').monitoredServices;
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local serviceAggregation = aggregationSets.serviceSLIs;
local selectors = import 'promql/selectors.libsonnet';

local outputPromYaml(groups) =
  std.manifestYamlDoc({ groups: groups });

local expr = |||
  %(ratioMetric)s{%(selector)s}
  %(comparisonOperator)s bool on(tier, type) group_left
  %(slo)s{%(selectorWithoutEnv)s}
|||;

local errorRatioExpression(service, selector) =
  expr % {
    ratioMetric: serviceAggregation.getErrorRatioMetricForBurnRate('5m'),
    selector: selectors.serializeHash(selector),
    comparisonOperator: '<=',
    slo: 'slo:max:gitlab_service_errors:ratio',
    selectorWithoutEnv: selectors.serializeHash(selectors.without(selector, ['env'])),
  };

local apdexRatioExpression(service, selector) =
  expr % {
    ratioMetric: serviceAggregation.getApdexRatioMetricForBurnRate('5m'),
    selector: selectors.serializeHash(selector),
    comparisonOperator: '>=',
    slo: 'slo:min:gitlab_service_apdex:ratio',
    selectorWithoutEnv: selectors.serializeHash(selectors.without(selector, ['env'])),
  };

local rulesForService(service, selector) =
  local selectorWithAggregationSetSelector = selectors.merge(selector, serviceAggregation.selector);
  [
    {
      record: 'slo:observation_status',
      labels: { slo: 'apdex_ratio' },
      expr: apdexRatioExpression(service, selectorWithAggregationSetSelector),
    },
    {
      record: 'slo:observation_status',
      labels: { slo: 'error_ratio' },
      expr: errorRatioExpression(service, selectorWithAggregationSetSelector),
    },
  ];

local groupsForService(service, selector) =
  [
    {
      name: 'GitLab Apdex SLO observance status',
      interval: '1m',
      rules: rulesForService(service, selector { type: service.type }),
    },
  ];

local fileForService(service, selector, _extraArgs, _) =
  {
    'service-slo-observance': outputPromYaml(groupsForService(service, selector)),
  };

local servicesWithContractualThresholds = std.filter(
  function(service) std.objectHas(service, 'contractualThresholds'),
  monitoredServices
);
std.foldl(
  function(memo, service)
    memo + separateMimirRecordingFiles(
      fileForService,
      service,
    ),
  servicesWithContractualThresholds,
  {}
)
