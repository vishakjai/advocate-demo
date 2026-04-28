local grafanaDefaults = { baseURL: 'https://dashboards.gitlab.net/d' };

local overviewDashboard(service, baseURL=grafanaDefaults.baseURL) =
  {
    name: '%(service)s Service Overview Dashboard' % { service: service },
    url: '%(baseURL)s/%(service)s-main' % { service: service, baseURL: baseURL },
  };

local resourceDashboard(service, dashboard_uid, component, baseURL=grafanaDefaults.baseURL) =
  {
    name: '%(service)s Service | %(component)s resource Dashboard' % {
      service: service,
      component: component,
    },
    url: '%(baseURL)s/alerts-%(dashboard_uid)s/?var-environment=gprd&var-type=%(service)s&var-stage=main&var-component=%(component)s' % {
      service: service,
      dashboard_uid: dashboard_uid,
      component: component,
      baseURL: baseURL,
    },
  };

{
  overviewDashboard:: overviewDashboard,
  resourceDashboard:: resourceDashboard,
  defaults:: grafanaDefaults,
}
