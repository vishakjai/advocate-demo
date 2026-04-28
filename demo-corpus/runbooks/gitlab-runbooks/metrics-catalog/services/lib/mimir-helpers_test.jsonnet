local mimirHelpers = import './mimir-helpers.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testMimirDatasourceWithDash: {
    actual: mimirHelpers.mimirDatasource('gitlab-gprd'),
    expect: 'Mimir - Gitlab Gprd',
  },
  testMimirDataSourceWithoutDash: {
    actual: mimirHelpers.mimirDatasource('runway'),
    expect: 'Mimir - Runway',
  },
})
