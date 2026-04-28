local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local selector = { env: '$environment', stage: '$stage', type: 'kas' };
local selectorString = selectors.serializeHash(selector);

basic.dashboard(
  'Kubernetes API Proxy',
  tags=[
    'kas',
  ],
)
.addTemplate(templates.stage)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Request Volume',
        description='Kubernetes API Proxy total request volume.',
        query=|||
          sum(rate(k8s_api_proxy_requests_total{%s}[$__rate_interval]))
        ||| % selectorString,
        yAxisLabel='requests',
        legend_show=false,
      ),
      basic.gaugePanel(
        'Success Rate',
        query=|||
          sum(rate(k8s_api_proxy_requests_success_total{%(selector)s}[$__rate_interval])) /
          sum(rate(k8s_api_proxy_requests_total{%(selector)s}[$__rate_interval])) * 100
        ||| % { selector: selectorString },
        instant=false,
        unit='percent',
      ),
      basic.gaugePanel(
        'Error Rate',
        query=|||
          sum(rate(k8s_api_proxy_requests_error_total{%(selector)s}[$__rate_interval])) /
          sum(rate(k8s_api_proxy_requests_total{%(selector)s}[$__rate_interval])) * 100
        ||| % { selector: selectorString },
        instant=false,
        unit='percent',
      ),
      panel.multiTimeSeries(
        title='Success vs. Error Rates',
        description='Kubernetes API Proxy successful vs. error requests.',
        queries=[
          {
            legendFormat: 'Success',
            query: |||
              sum(rate(k8s_api_proxy_requests_success_total{%s}[$__rate_interval]))
            ||| % selectorString,
          },
          {
            legendFormat: 'Error',
            query: |||
              sum(rate(k8s_api_proxy_requests_error_total{%s}[$__rate_interval]))
            ||| % selectorString,
          },
        ],
        format='short',
        interval='1m',
        intervalFactor=2,
        legend_show=false,
      ),
      panel.timeSeries(
        'Status Code Class Distribution',
        query=|||
          sum by (status_code_class) (increase(k8s_api_proxy_requests_success_total{%s}[$__rate_interval]))
        ||| % selectorString,
        yAxisLabel='requests',
        legend_show=false,
      ),
      panel.timeSeries(
        'Error Type Distribution',
        query=|||
          sum by (error_type) (increase(k8s_api_proxy_requests_error_total{%s}[$__rate_interval]))
        ||| % selectorString,
        yAxisLabel='requests',
        legend_show=false,
      ),
    ],
    cols=3,
    rowHeight=10,
  )
)
