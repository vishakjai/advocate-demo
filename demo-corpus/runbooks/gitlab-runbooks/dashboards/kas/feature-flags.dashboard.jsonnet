local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local selector = { env: '$environment', stage: '$stage', type: 'kas' };
local selectorString = selectors.serializeHash(selector);

basic.dashboard(
  'Feature Flags',
  tags=[
    'kas',
  ],
)
.addTemplate(templates.stage)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Feature Flags',
        description='Feature Flag checks in KAS',
        query=|||
          sum(rate(kas_feature_flag_checks_total{%(selector)s}[$__rate_interval])) by (name, enabled)
        ||| % { selector: selectorString },
        legendFormat='{{name}}: {{enabled}}',
      ),
    ],
    cols=1,
    rowHeight=20,
  )
)
