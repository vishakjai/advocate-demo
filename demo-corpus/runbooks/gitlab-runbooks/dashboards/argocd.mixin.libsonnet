local argocd = import 'github.com/adinhodovic/argo-cd-mixin/mixin.libsonnet';

local dashboards = argocd {
  _config+:: {
    datasourceName: 'mimir-gitlab-ops',
    grafanaUrl: 'https://dashboards.gitlab.net',
    argoCdUrl: 'https://argocd.gitlab.net',
    tags: ['argocd', 'argo-cd', 'kubernetes', 'type:argocd'],
    alerts+: {
      enabled: false,
    },
  },
}.grafanaDashboards;

{
  [name]: dashboards[name] {
    uid: null,
  }
  for name in std.objectFields(dashboards)
}
