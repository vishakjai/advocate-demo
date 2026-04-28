local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local timeSeriesPanel = import 'grafana/time-series/panel.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local row = grafana.row;
local mimirHelpers = import 'services/lib/mimir-helpers.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;

local panels = {
  quotaDecisionsByResult: timeSeriesPanel.percentageTimeSeries(
    title='Quota Decisions by Result',
    query='%s / ignoring(result) group_left sum(%s)' % [
      rateMetric(counter='usage_quota_check_total', selector={}, useRecordingRuleRegistry=false)
      .aggregatedRateQuery(['result'], {}, '$__interval'),
      rateMetric(counter='usage_quota_check_total', selector={}, useRecordingRuleRegistry=false)
      .rateQuery({}, '$__interval'),
    ],
    yAxisLabel='percentage',
    legendFormat='{{ result }}',
    fill=50,
    stack=true,
  ),

  quotaDenialsByRealm: timeSeriesPanel.timeSeries(
    title='Quota Denials by Realm',
    query=rateMetric(
      counter='usage_quota_check_total',
      selector={ result: 'deny' },
      useRecordingRuleRegistry=false,
    ).aggregatedRateQuery(['realm'], {}, '$__interval'),
    yAxisLabel='denials/sec',
    legendFormat='{{ realm }}',
    fill=50,
    stack=true,
  ),

  failOpenDecisions: timeSeriesPanel.timeSeries(
    title='Fail-Open Decisions',
    query=rateMetric(counter='usage_quota_check_total', selector={ result: 'fail_open' }, useRecordingRuleRegistry=false)
          .aggregatedRateQuery(['realm'], {}, '$__interval'),
    yAxisLabel='fail-opens/sec',
    legendFormat='{{ realm }}',
    fill=50,
    stack=true,
  ),

  customersdotRequestsByOutcome: timeSeriesPanel.timeSeries(
    title='CustomersDot Requests by Outcome',
    query=rateMetric(counter='usage_quota_customersdot_requests_total', selector={}, useRecordingRuleRegistry=false)
          .aggregatedRateQuery(['outcome'], {}, '$__interval'),
    yAxisLabel='requests/sec',
    legendFormat='{{ outcome }}',
    fill=50,
    stack=true,
  ),

  customersdotRequestsByStatus: timeSeriesPanel.timeSeries(
    title='CustomersDot Requests by Status',
    query=rateMetric(counter='usage_quota_customersdot_requests_total', selector={}, useRecordingRuleRegistry=false)
          .aggregatedRateQuery(['status'], {}, '$__interval'),
    yAxisLabel='requests/sec',
    legendFormat='{{ status }}',
    fill=50,
    stack=true,
  ),

  customersdotLatencyP95: timeSeriesPanel.latencyTimeSeries(
    title='CustomersDot Latency - p95',
    query='histogram_quantile(0.95, %s)' % rateMetric(counter='usage_quota_customersdot_latency_seconds_bucket', selector={}, useRecordingRuleRegistry=false)
                                           .aggregatedRateQuery(['le'], {}, '$__interval'),
    yAxisLabel='seconds',
    format='s',
    legendFormat='p95',
  ),

  avgCustomersdotLatency: timeSeriesPanel.latencyTimeSeries(
    title='Average CustomersDot Latency',
    query='%s / %s' % [
      rateMetric(counter='usage_quota_customersdot_latency_seconds_sum', selector={}, useRecordingRuleRegistry=false)
      .aggregatedRateQuery([], {}, '$__interval'),
      rateMetric(counter='usage_quota_customersdot_latency_seconds_count', selector={}, useRecordingRuleRegistry=false)
      .aggregatedRateQuery([], {}, '$__interval'),
    ],
    yAxisLabel='seconds',
    format='s',
    legendFormat='avg latency',
  ),
};

local quotaDecisionsGridded = layout.grid([panels.quotaDecisionsByResult], cols=1, rowHeight=10, startRow=1);
local quotaDenialsGridded = layout.grid([panels.quotaDenialsByRealm, panels.failOpenDecisions], cols=2, rowHeight=10, startRow=101);
local customersdotIntegrationGridded = layout.grid([panels.customersdotRequestsByOutcome, panels.customersdotRequestsByStatus], cols=2, rowHeight=10, startRow=201);
local customersdotLatencyGridded = layout.grid([panels.customersdotLatencyP95, panels.avgCustomersdotLatency], cols=2, rowHeight=10, startRow=301);

grafana.dashboard
.new(title='Usage Quota')
.addTemplate(template.custom(name='PROMETHEUS_DS', label='PROMETHEUS_DS', query=mimirHelpers.mimirDatasource('runway'), current=mimirHelpers.mimirDatasource('runway')))
.addTemplate(template.custom(name='environment', label='environment', query='gstg,gprd,stgsub,prdsub', current='gstg'))
.addPanel(row.new(title='Quota Decisions'), gridPos={ x: 0, y: 0, w: 24, h: 1 })
.addPanels(quotaDecisionsGridded)
.addPanel(row.new(title='Quota Denials'), gridPos={ x: 0, y: 100, w: 24, h: 1 })
.addPanels(quotaDenialsGridded)
.addPanel(row.new(title='CustomersDot Integration'), gridPos={ x: 0, y: 200, w: 24, h: 1 })
.addPanels(customersdotIntegrationGridded)
.addPanel(row.new(title='CustomersDot Latency'), gridPos={ x: 0, y: 300, w: 24, h: 1 })
.addPanels(customersdotLatencyGridded)
