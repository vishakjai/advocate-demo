local mappingWithOverride = import 'stage-group-mapping-with-overrides.jsonnet';
local test = import 'test.libsonnet';

test.suite({
  testLookupByInexistentGroup: {
    actual: std.get(mappingWithOverride, 'asdf', null),
    expect: null,
  },
  testLookupByUntouchedGroup: {
    actual: mappingWithOverride.observability,
    expectContains: {
      stage: 'production_engineering',
      feature_categories: [
        'capacity_planning',
        'error_budgets',
        'scalability',
      ],
    },
  },
  testLookupByMergeGroup: {
    actual: mappingWithOverride.gitaly,
    expectContains: {
      stage: 'tenant_scale',
      feature_categories: ['gitaly', 'git'],  // feature categories collected by source group(s)
    },
  },
})
