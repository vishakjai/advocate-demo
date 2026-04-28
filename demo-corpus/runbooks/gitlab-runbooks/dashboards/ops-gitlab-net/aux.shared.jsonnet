local auxDashboards = import 'gitlab-dashboards/aux_dashboards.libsonnet';

auxDashboards.forService(
  'ops-gitlab-net',
  environmentSelectorHash={},
)
