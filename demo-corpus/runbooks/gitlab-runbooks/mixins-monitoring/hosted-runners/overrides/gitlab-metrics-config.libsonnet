local aggregationSets = import 'reference-aggregation-sets.libsonnet';
local referenceArchitecturesGitLabConfig = import 'runbooks/reference-architectures/get-hybrid/src/gitlab-metrics-config.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';
local labelSet = (import 'label-taxonomy/label-set.libsonnet');
local options = import 'gitlab-metrics-options.libsonnet';

referenceArchitecturesGitLabConfig {
  monitoredServices: [
    import '../services/runner.libsonnet',
    import '../services/logging.libsonnet',
  ],

  saturationMonitoring+: import '../services/runner-saturation.libsonnet',

  labelTaxonomy:: labelSet.makeLabelSet({
    environmentThanos: null,  // No thanos
    environment: null,  // Only one environment
    tier: null,  // No tiers
    service: 'type',
    stage: null,  // No stages
    shard: 'shard',
    node: null,  // No node
    sliComponent: 'component',
  }),
}
