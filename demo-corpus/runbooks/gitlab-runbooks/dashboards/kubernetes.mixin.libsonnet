local kubernetes = import 'github.com/kubernetes-monitoring/kubernetes-mixin/mixin.libsonnet';

local
  mixin = kubernetes {
    _config+:: {
      cadvisorSelector: 'job="kubelet"',
      kubeApiserverSelector:: 'job="apiserver"',
      grafanaK8s+:: {
        dashboardNamePrefix: '',
        dashboardTags: ['kubernetes', 'infrastucture'],
      },
      showMultiCluster: true,
    },
  },
  dashboards = mixin.grafanaDashboards;

// Perform custom modifications to the dashboard to suit the GitLab Grafana deployment,
// and filter out unused dashboards
{
  [std.strReplace(name, 'k8s-', '')]: dashboards[name] {
    uid: null,
  }
  for name in std.filter(
    function(name)
      std.length(std.findSubstr('-windows-', name)) == 0
      && name != 'controller-manager.json'
      && name != 'proxy.json'
      && name != 'scheduler.json',
    std.objectFields(dashboards)
  )
}
