local gitalyHelper = import 'service-archetypes/helpers/gitaly.libsonnet';
local validator = import 'utils/validator.libsonnet';

// This provides a validator, plus defaults for
// `gitlab-metrics-options.libsonnet`. For details, please refer to the README.md file at
// https://runbooks.gitlab.com/reference-architectures/.

local defaults = {
  // NOTE: when updating this option set, please ensure that the
  // documentation regarding options is updated at
  // reference-architectures/README.md#options
  elasticacheMonitoring: false,
  praefect: {
    // The reference architecture makes Praefect/Gitaly-Cluster optional
    // Override this to disable Praefect monitoring
    enable: true,
  },
  consul: {
    enable: true,
  },
  rdsMonitoring: false,

  toolingLinks: {
    opensearchHostname: null,  // null means no links are generated in Grafana dashboards.
    defaultIndexPattern: null,  // The index pattern name where relevant logs are stored; required if hostname is not null
    indexPatterns: {},  // Optional map of index catalog entry names to index patterns, to override the defaultIndexPattern if necessary
  },

  monitoring: {
    sidekiq: {},
  },

  apdexThresholds: {
    gitlabShell: {
      satisfied: 30,
      tolerated: 60,
    },
    gitaly: {
      satisfied: gitalyHelper.defaultSatisfiedThreshold,
      tolerated: gitalyHelper.defaultToleratedThreshold,
    },
    praefect: {
      satisfied: gitalyHelper.defaultSatisfiedThreshold,
      tolerated: gitalyHelper.defaultToleratedThreshold,
    },
  },
};

local referenceArchitectureOptionsValidator = validator.new({
  elasticacheMonitoring: validator.boolean,
  praefect: {
    enable: validator.boolean,
  },
  consul: {
    enable: validator.boolean,
  },
  rdsMonitoring: validator.boolean,
});

function(overrides)
  local v = defaults + overrides;
  referenceArchitectureOptionsValidator.assertValid(v)
