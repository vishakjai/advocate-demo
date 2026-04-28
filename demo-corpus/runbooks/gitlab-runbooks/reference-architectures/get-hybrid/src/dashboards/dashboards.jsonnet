local serviceDashboard = import 'gitlab-dashboards/service_dashboard.libsonnet';
local services = (import 'gitlab-metrics-config.libsonnet').monitoredServices;

std.foldl(
  function(memo, service)
    memo {
      ['dashboards/%(type)s.json' % service]:
        serviceDashboard.overview(
          service.type,
          title='%(type)s Service Overview' % service,
          showProvisioningDetails=false,
          showSystemDiagrams=false,
          uid='%(type)s-main' % service,
        )
        .overviewTrailer(),
    },
  services,
  {
    'dashboards/triage.json': import 'triage.libsonnet',
    'dashboards/occurence-slas.json': import 'occurence-slas.libsonnet',
  }
)
