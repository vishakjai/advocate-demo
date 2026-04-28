local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local template = grafana.template;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

basic.dashboard(
  'Runway Cloudflare Metrics',
  tags=['runway', 'type:runway', 'cloudflare'],
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-ops')
)
.addTemplate(
  template.new(
    'runway_zone',
    '$PROMETHEUS_DS',
    'label_values(cloudflare_zone_uniques_total{account="gitlab-runway"},zone)',
    refresh='load',
    sort=1,
  )
)
.addPanels(
  layout.grid([
    panel.timeSeries(
      title='Total Requests',
      description='Requests per second per zone',
      yAxisLabel='Requests per Second',
      query=|||
        sum by(zone) (
          rate(cloudflare_zone_requests_total{account="gitlab-runway", zone="$runway_zone"}[$__rate_interval])
        )
      |||,
      legendFormat='{{zone}}',
      intervalFactor=2,
    ),
    panel.timeSeries(
      title='Total Bandwidth',
      description='Bandwidth per second per zone',
      yAxisLabel='Bytes per Second',
      query=|||
        sum by(zone) (
          rate(cloudflare_zone_bandwidth_total{account="gitlab-runway", zone="$runway_zone"}[$__rate_interval])
        )
      |||,
      legendFormat='{{zone}}',
      format='Bps',
      intervalFactor=2,
    ),
    panel.timeSeries(
      title='Requests by Status',
      description='Requests per second grouped by HTTP status code',
      yAxisLabel='Requests per Second',
      query=|||
        sum by(status) (
          rate(cloudflare_zone_requests_status{account="gitlab-runway", zone="$runway_zone"}[$__rate_interval])
        )
      |||,
      legendFormat='HTTP {{status}}',
      intervalFactor=2,
    ),
    panel.timeSeries(
      title='Unique Visitors',
      description='Unique visitors per second per zone',
      yAxisLabel='Visitors per Second',
      query=|||
        sum by(zone) (
          rate(cloudflare_zone_uniques_total{account="gitlab-runway", zone="$runway_zone"}[$__rate_interval])
        )
      |||,
      legendFormat='{{zone}}',
      intervalFactor=2,
    ),
    panel.timeSeries(
      title='Zone Pools RPS',
      description='Requests per second per load balancer and pool',
      yAxisLabel='Requests per Second',
      query=|||
        sum by(load_balancer_name, pool_name) (
          rate(cloudflare_zone_pool_requests_total{account="gitlab-runway", zone="$runway_zone"}[$__rate_interval])
        )
      |||,
      legendFormat='{{load_balancer_name}} - {{pool_name}}',
      intervalFactor=2,
    ),
    basic.statPanel(
      title='',
      panelTitle='Zone Pools Status',
      color=[
        { value: null, color: 'semi-dark-red' },
        { value: 1, color: 'semi-dark-green' },
      ],
      query=|||
        sum by(load_balancer_name, pool_name) (
          cloudflare_zone_pool_health_status{account="gitlab-runway", zone="$runway_zone"}
        )
      |||,
      legendFormat='{{load_balancer_name}} - {{pool_name}}',
      orientation='horizontal',
      mappings=[
        {
          type: 'value',
          options: {
            '0': { text: 'DOWN', color: 'semi-dark-red', index: 0 },
            '1': { text: 'UP', color: 'semi-dark-green', index: 1 },
          },
        },
      ],
    ),
  ])
)
