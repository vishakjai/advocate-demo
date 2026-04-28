local grafana = import './grafana.libsonnet';
local test = import 'test.libsonnet';

test.suite({
  testOverviewDashboardWithDefaults: {
    actual: grafana.overviewDashboard('web'),
    expectContains: {
      name: 'web Service Overview Dashboard',
      url: 'https://dashboards.gitlab.net/d/web-main',
    },
  },
  testOverviewDashboardWithCustomBaseURL: {
    local baseURL = 'http://localhost:666/',
    actual: grafana.overviewDashboard('web', baseURL=baseURL),
    expectContains: {
      name: 'web Service Overview Dashboard',
      url: '%(baseURL)s/web-main' % { baseURL: baseURL },
    },
  },
  testResourceDashboardWithDefaults: {
    actual: grafana.resourceDashboard('web', 'sat_kube_container_cpu', 'kube_container_cpu'),
    expectContains: {
      name: 'web Service | kube_container_cpu resource Dashboard',
      url: 'https://dashboards.gitlab.net/d/alerts-sat_kube_container_cpu/?var-environment=gprd&var-type=web&var-stage=main&var-component=kube_container_cpu',
    },
  },
  testResourceDashboardWithCustomBaseURL: {
    local baseURL = 'http://localhost:666/',
    actual: grafana.resourceDashboard('web', 'sat_kube_container_cpu', 'kube_container_cpu', baseURL=baseURL),
    expectContains: {
      name: 'web Service | kube_container_cpu resource Dashboard',
      url: '%(baseURL)s/alerts-sat_kube_container_cpu/?var-environment=gprd&var-type=web&var-stage=main&var-component=kube_container_cpu' % { baseURL: baseURL },
    },
  },
})
