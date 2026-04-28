local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local gaugePanel = grafana.gaugePanel;
local promQuery = import 'grafana/prom_query.libsonnet';
local aggregations = import 'promql/aggregations.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local override = import 'grafana/time-series/override.libsonnet';

local jobSaturationMetrics = {
  concurrent: 'gitlab_runner_concurrent',
  limit: 'gitlab_runner_limit',
};

local aggregatorLegendFormat(aggregator) = '{{ %s }}' % aggregator;

local runnerSaturation(aggregators, saturationType) =
  local serializedAggregation = aggregations.serialize(aggregators);
  panel.timeSeries(
    title='Runner saturation of %(type)s by %(aggregator)s' % { aggregator: serializedAggregation, type: saturationType },
    description='Ratio of running jobs to the configured %s ceiling, with soft (85%%) and hard (90%%) SLO thresholds. Values above the soft SLO mean the runner is nearing capacity.' % saturationType,
    legendFormat='%(aggregators)s' % { aggregators: std.join(' - ', std.map(aggregatorLegendFormat, aggregators)) },
    format='percentunit',
    query=|||
      sum by (%(aggregator)s) (
        gitlab_runner_jobs{environment="$environment", stage="$stage", job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner", shard=~"${shard:pipe}"}
      )
      /
      sum by (%(aggregator)s) (
        %(maxJobsMetric)s{environment="$environment", stage="$stage", job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner", shard=~"${shard:pipe}"}
      )
    ||| % {
      aggregator: serializedAggregation,
      maxJobsMetric: jobSaturationMetrics[saturationType],
    },
  ).addTarget(
    target.prometheus(
      expr='0.85',
      legendFormat='Soft SLO',
    )
  ).addTarget(
    target.prometheus(
      expr='0.9',
      legendFormat='Hard SLO',
    )
  ).addSeriesOverride(
    override.hardSlo
  ).addSeriesOverride(
    override.softSlo
  );

local runnerSaturationCounter() =
  gaugePanel.new(
    title='Runner managers mean saturation',
    description='Mean saturation (running jobs / concurrent) across all runner managers, displayed as a gauge. Green < 75%, yellow 75-90%, red > 90%.',
    datasource='$PROMETHEUS_DS',
    reducerFunction='mean',
    showThresholdMarkers=true,
    unit='percentunit',
    min=0,
    max=1,
    decimals=1,
    pluginVersion='7.2.0',
  )
  .addTarget(promQuery.target(
    expr=|||
      sum by(shard) (gitlab_runner_jobs{environment="$environment", stage="$stage", job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner", shard=~"${shard:pipe}"})
      /
      sum by(shard) (gitlab_runner_concurrent{environment="$environment", stage="$stage", job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner", shard=~"${shard:pipe}"})
    |||,
    legendFormat='{{shard}}',
    interval='1d',
    intervalFactor=1,
  ))
  .addThresholds([
    {
      color: 'green',
      value: null,
    },
    {
      color: '#EAB839',
      value: 0.75,
    },
    {
      color: 'red',
      value: 0.9,
    },
  ]);

{
  runnerSaturation:: runnerSaturation,
  runnerSaturationCounter:: runnerSaturationCounter,
}
