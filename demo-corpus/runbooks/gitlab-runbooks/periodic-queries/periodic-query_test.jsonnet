local periodicQueries = import './periodic-query.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testDefaults: {
    actual: periodicQueries.new({
      requestParams: {
        query: 'promql',
      },
    }),
    expect: {
      requestParams: {
        query: 'promql',
      },
      type: 'instant',
      tenantId: 'gitlab-gprd',
    },
  },
})
