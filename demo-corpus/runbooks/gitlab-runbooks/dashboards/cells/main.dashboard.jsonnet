local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local colorScheme = import 'grafana/color_scheme.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local threshold = import 'grafana/time-series/threshold.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';

local row = grafana.row;
local text = grafana.text;
local dashboardHelpers = import 'stage-groups/verify-runner/dashboard_helpers.libsonnet';

basic.dashboard(
  'Cells Performance',
  tags=['cells', 'performance'],
  includeEnvironmentTemplate=true,
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-ops'),
)

.addPanel(
  text.new(
    title='Cells Performance Dashboard',
    mode='markdown',
    content=|||
      [Observability based performance analysis](https://handbook.gitlab.com/handbook/engineering/infrastructure-platforms/cells/cells_test_strategy/#observability-testing) provides a view into how performance has been to help identify problems before they become customer facing problems.

      This dashboard provides a vew into https://staging.gitlab.com
    |||
  ),
  gridPos={
    x: 0,
    y: 0,
    w: 24,
    h: 3,
  },
)

.addPanels(layout.grid([
  basic.gaugePanel(
    stableId='pingdom-response-gauge',
    title='Current End User Response Time (ms)',
    description='The End User Response Time as measured by Pingdom. We currently do not have a threshold defined for pingdom metrics so using the request urgency thresholds to provide scaling: https://docs.gitlab.com/ee/development/application_slis/rails_request.html#how-to-adjust-the-urgency',
    query=|||
      pingdom_uptime_response_time_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"} * 1000
    |||,
    legendFormat='check:https://staging.gitlab.com/cdn-cgi/trace',
    instant=false,
    unit='ms',
    max=6000,
    color=[
      { color: colorScheme.normalRangeColor, value: null },
      { color: colorScheme.warningColor, value: 250 },
      { color: colorScheme.primaryMetricColor, value: 500 },
      { color: colorScheme.errorColor, value: 1000 },
      { color: colorScheme.criticalColor, value: 5000 },
    ],
  ),
  basic.gaugePanel(
    stableId='cloudflare-latency-gauge',
    title='Cloudflare Latency (P999)',
    description='The Latency on requests caused by Cloudflare. We are using 5 ms as the acceptable delay threshold.',
    query=|||
      cloudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router", quantile="P999"}
    |||,
    instant=false,
    unit='µs',
    max=6000,
    color=[
      { color: colorScheme.normalRangeColor, value: null },
      { color: colorScheme.criticalColor, value: 5000 },
    ],
  ),
], cols=2, rowHeight=6))

.addPanel(
  text.new(
    mode='markdown',
    content=|||
      These graphs gives us a view into these metrics over several time slices. This give us the ability to see if performance has changed over time.

      They show results from today, yesterday, 7 days ago, and 30 days ago.
    |||
  ),
  gridPos={
    x: 0,
    y: 500,
    w: 24,
    h: 4,
  },
)

.addPanels(
  layout.grid(
    [
      panel.multiTimeSeries(
        stableId='pingdom_latency_over_time',
        title='Pingdom Latency over time (P999)',
        description='This graph shows the Pingdom response times measured from the endpoints',
        datasource=mimirHelper.mimirDatasource('gitlab-ops'),
        format='ms',
        queries=[
          {
            legendFormat: 'Today',
            query: '(pingdom_uptime_response_time_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"}) * 1000',
          },
          {
            legendFormat: 'Yesterday',
            query: '(pingdom_uptime_response_time_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"} offset 1d) * 1000',
          },
          {
            legendFormat: '7 Days Ago',
            query: '(pingdom_uptime_response_time_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"} offset 7d) * 1000',
          },
          {
            legendFormat: '30 Days Ago',
            query: '(pingdom_uptime_response_time_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"} offset 30d) * 1000',
          },
        ],
      ),
      panel.multiTimeSeries(
        stableId='cloudflare_latency_over_time',
        title='Cloudflare Latency over time (P999)',
        description='This graph shows the Cloudflare induced latency, the CloudFlare defintion of this metric: https://developers.cloudflare.com/workers/observability/metrics-and-analytics/#cpu-time-per-execution',
        datasource=mimirHelper.mimirDatasource('gitlab-ops'),
        queries=[
          {
            legendFormat: 'Today',
            query: 'cloudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router",quantile="P999",service="cloudflare-exporter-gitlab-com"} ',
          },
          {
            legendFormat: 'Yesterday',
            query: 'cloudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router",quantile="P999",service="cloudflare-exporter-gitlab-com"} offset 1d',
          },
          {
            legendFormat: '7 Days Ago',
            query: 'cloudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router",quantile="P999",service="cloudflare-exporter-gitlab-com"} offset 7d',
          },
          {
            legendFormat: '30 Days Ago',
            query: 'loudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router",quantile="P999",service="cloudflare-exporter-gitlab-com"} offset  30d',
          },
        ],
        format='µs',
      ),
      panel.multiTimeSeries(
        title='Cloudflare Errors per Timeslice',
        description='This graph shows the Cloudflare error rate, the CloudFlare defintion of the request statuses: https://developers.cloudflare.com/workers/observability/metrics-and-analytics/#invocation-statuses',
        datasource=mimirHelper.mimirDatasource('gitlab-ops'),
        queries=[
          {
            legendFormat: 'Today',
            query: 'rate(cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router",service="cloudflare-exporter-gitlab-com"}[$__rate_interval])',
          },
          {
            legendFormat: 'Yesterday',
            query: 'rate(cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router",service="cloudflare-exporter-gitlab-com"}[$__rate_interval] offset 1d)',
          },
          {
            legendFormat: '7 Days Ago',
            query: 'rate(cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router",service="cloudflare-exporter-gitlab-com"}[$__rate_interval] offset 7d)',
          },
          {
            legendFormat: '30 Days Ago',
            query: 'rate(cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router",service="cloudflare-exporter-gitlab-com"}[$__rate_interval] offset 30d)',
          },
        ],
      ),
      panel.multiTimeSeries(
        title='CloudFlare Error Totals',
        description='This graph shows the Cloudflare total number of errors, the CloudFlare defintion of the request statuses: https://developers.cloudflare.com/workers/observability/metrics-and-analytics/#invocation-statuses',
        datasource=mimirHelper.mimirDatasource('gitlab-ops'),
        queries=[
          {
            legendFormat: 'Today',
            query: 'cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router",service="cloudflare-exporter-gitlab-com"}',
          },
          {
            legendFormat: 'Yesterday',
            query: 'cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router",service="cloudflare-exporter-gitlab-com"} offset 1d',
          },
          {
            legendFormat: '7 Days Ago',
            query: 'cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router",service="cloudflare-exporter-gitlab-com"} offset 7d',
          },
          {
            legendFormat: '30 Days Ago',
            query: 'cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router",service="cloudflare-exporter-gitlab-com"} offset 30d',
          },
        ],
      ),
    ],
    cols=2,
    rowHeight=12,
    startRow=510,
  )
)

.addPanel(
  row.new(title='Pingdom', collapse=true).addPanels(
    layout.grid(
      [
        basic.gaugePanel(
          stableId='pingdom-response-gauge-1',
          title='Current End User Response Time (ms)',
          description='We currently do not have a threshold defined for pingdom metrics so using the request urgency thresholds to provide scaling: https://docs.gitlab.com/ee/development/application_slis/rails_request.html#how-to-adjust-the-urgency',
          query=|||
            pingdom_uptime_response_time_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"} * 1000
          |||,
          legendFormat='check:https://staging.gitlab.com/cdn-cgi/trace',
          instant=false,
          unit='ms',
          max=6000,
          color=[
            { color: colorScheme.normalRangeColor, value: null },
            { color: colorScheme.warningColor, value: 250 },
            { color: colorScheme.primaryMetricColor, value: 500 },
            { color: colorScheme.errorColor, value: 1000 },
            { color: colorScheme.criticalColor, value: 5000 },
          ],
        ),
        panel.timeSeries(
          stableId='pingdom_response_time',
          title='Pingdom Response Time',
          description='We currently do not have a threshold defined for pingdom metrics so using the request urgency thresholds to provide scaling: https://docs.gitlab.com/ee/development/application_slis/rails_request.html#how-to-adjust-the-urgency',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            pingdom_uptime_response_time_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"} * 1000
          |||,
          legendFormat='response time',
          thresholdSteps=[
            {
              value: null,
              color: '#3e7d36fc',
            },
            {
              value: 250,
              color: '#b3b300fc',
            },
            {
              value: 500,
              color: '#9d8d15fc',
            },
            {
              value: 1000,
              color: '#b35900fc',
            },
            {
              value: 5000,
              color: colorScheme.criticalColor + 'fc',
            },
          ],
          format='ms',
        ),
      ],
      cols=1,
      rowHeight=12,
      startRow=1100,
    )
  ).addPanels(
    layout.grid(
      [
        panel.timeSeries(
          stableId='pingdom_outages',
          title='Pingdom Outages',
          description='Monitoring Outages for Pingdom service',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            pingdom_outages_total{name="check:https://staging.gitlab.com/cdn-cgi/trace"}
          |||,
          legendFormat='outages',
        ),
        panel.timeSeries(
          stableId='pingdom_slo_budget',
          title='SLO Error Budget',
          description='Monitoring SLO Error budget for Pingdom service',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            pingdom_uptime_slo_error_budget_available_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"}
          |||,
          legendFormat='available',
          format='short',
        ).addTarget(
          target.prometheus(
            |||
              pingdom_uptime_slo_error_budget_total_seconds{name="check:https://staging.gitlab.com/cdn-cgi/trace"}
            |||,
            legendFormat='total',
          )
        ),
        panel.timeSeries(
          stableId='pingdom_rate_limit',
          title='Pingdom API Rate Limit',
          description='Number of requests left for the Pingdom rate limit',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            pingdom_rate_limit_remaining_requests{}
          |||,
          legendFormat='rate limit remaining',
        ),
      ],
      cols=2,
      rowHeight=12,
      startRow=1200,
    )
  ),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  },
)

.addPanel(
  row.new(title='CloudFlare', collapse=true).addPanels(
    layout.grid(
      [
        basic.gaugePanel(
          stableId='cloudflare-current-cpu-latency',
          title='Current CPU Latency (P999)',
          query=|||
            cloudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router", quantile="P999"}
          |||,
          instant=false,
          unit='µs',
          max=6000,
          color=[
            { color: colorScheme.normalRangeColor, value: null },
            { color: colorScheme.criticalColor, value: 5000 },
          ],
        ),
        basic.gaugePanel(
          stableId='cloudflare-latency-headroom',
          title='CPU latency headroom (P999)',
          description='Headroom calculation: https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/cells/http_routing_service/#analysis',
          query=|||
            50000- max(cloudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router", quantile="P999"})
          |||,
          instant=false,
          unit='µs',
          max=6000,
          color=[
            { color: colorScheme.normalRangeColor, value: null },
            { color: colorScheme.criticalColor, value: 5000 },
          ],
        ),
        panel.timeSeries(
          stableId='cloudflare-cpu-latency',
          description='CloudFlare definition: https://developers.cloudflare.com/workers/observability/metrics-and-analytics/#cpu-time-per-execution',
          title='CPU Latency',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            cloudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router"}
          |||,
          legendFormat='{{ quantile }}',
          format='µs',
          thresholdSteps=[
            threshold.optimalLevel(0),
            threshold.errorLevel(5000),
          ],
        ),
        panel.timeSeries(
          stableId='cloudflare-cpu-headroom',
          title='Worker CPU headroom',
          description='Headroom calculation: https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/cells/http_routing_service/#analysis',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            50000- cloudflare_worker_cpu_time{script_name=~"staging-gitlab-com-cells-http-router"}
          |||,
          legendFormat='{{ quantile }}',
          format='µs',
        ),
        panel.timeSeries(
          stableId='cloudflare-bandwidth-consumed',
          title='Bandwidth consumed',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            rate(cloudflare_zone_bandwidth_total{zone="staging.gitlab.com"}[5m])
          |||,
          legendFormat='bandwidth',
          format='bytes',
        ),
        panel.timeSeries(
          stableId='cloudflare-Requests',
          title='Requests',
          description='Cloudflare definition: https://developers.cloudflare.com/workers/observability/metrics-and-analytics/#requests',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            rate(cloudflare_worker_requests_count{script_name="staging-gitlab-com-cells-http-router"}[$__rate_interval])
          |||,
          legendFormat='Requests',
          thresholdSteps=[
            threshold.optimalLevel(0),
            threshold.errorLevel(80),
          ],
        ),
        panel.timeSeries(
          stableId='cloudflare-duration',
          description='CloudFlare definition: https://developers.cloudflare.com/workers/observability/metrics-and-analytics/#execution-duration-gb-seconds',
          title='Worker Duration',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            cloudflare_worker_duration{script_name="staging-gitlab-com-cells-http-router"}
          |||,
          legendFormat='{{ quantile }}',
          format='GBs',
        ),
        panel.timeSeries(
          stableId='cloudflare-worker-errors',
          title='CloudFlare Worker errors',
          description='CloudFlare documentation on request statuses: https://developers.cloudflare.com/workers/observability/metrics-and-analytics/#invocation-statuses',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            rate(cloudflare_worker_errors_count{script_name="staging-gitlab-com-cells-http-router"}[$__rate_interval])
          |||,
          legendFormat='rate of change',
        ),
        panel.timeSeries(
          stableId='cloudflare-requests_by_region',
          title='Requests by Region',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            sum by(region) (rate(cloudflare_zone_requests_country{zone='staging.gitlab.com'}[$__rate_interval]))
          |||,
          legendFormat='{{ region }}',
        ),
        panel.timeSeries(
          stableId='cloudflare-requests_by_country',
          title='Requests by country',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            rate(cloudflare_zone_requests_country{zone='staging.gitlab.com'}[$__rate_interval])
          |||,
          legendFormat='{{ country }}',
        ),
        panel.timeSeries(
          stableId='cloudflare-sli_aggregations',
          title='SLI aggregation: Request status (5m rate)',
          datasource=mimirHelper.mimirDatasource('gitlab-ops'),
          query=|||
            sli_aggregations:cloudflare_zone_requests_status:rate_5m{zone="staging.gitlab.com"}
          |||,
          legendFormat='{{ status }}',
        ),
      ],
      cols=2,
      rowHeight=12,
      startRow=2100,
    )
  ),
  gridPos={
    x: 0,
    y: 2000,
    w: 24,
    h: 1,
  },
)
.trailer()
+ {
  links+: [
    platformLinks.dynamicLinks('Cloudflare', 'type:cloudflare'),
    platformLinks.dynamicLinks('HTTP Router', 'type:http-router'),
  ] + platformLinks.services + platformLinks.triage,
}
