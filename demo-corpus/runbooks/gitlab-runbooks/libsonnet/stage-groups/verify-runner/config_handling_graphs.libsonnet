local helpers = import './helpers.libsonnet';
local threshold = import 'grafana/time-series/threshold.libsonnet';

local successes(title, metricName, aggregators) =
  helpers.aggregationTimeSeries(
    'Configuration %s success rate (by %%s)' % title,
    |||
      sum by(%%s) (
        increase(%(metricName)s{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"}[$__rate_interval])
      )
    ||| % { metricName: metricName },
    aggregators=aggregators,
    stack=false,
  );

local failures(title, metricName, aggregators, errorLevel=10) =
  helpers.aggregationTimeSeries(
    'Configuration %s failure rate (by %%s)' % title,
    |||
      sum by(%%s) (
        increase(%(metricName)s{environment=~"$environment",stage=~"$stage",shard=~"${shard:pipe}"}[$__rate_interval])
      )
    ||| % { metricName: metricName },
    aggregators=aggregators,
    stack=false,
    thresholdSteps=[
      threshold.errorLevel(errorLevel),
    ],
  );

local successfulReloads(aggregators=[]) =
  successes('reload', 'gitlab_runner_configuration_loaded_total', aggregators);

local reloadFailures(aggregators=[]) =
  failures('reload', 'gitlab_runner_configuration_loading_error_total', aggregators);

local successfulSaves(aggregators=[]) =
  successes('save', 'gitlab_runner_configuration_saved_total', aggregators);

local saveFailures(aggregators=[]) =
  failures('save', 'gitlab_runner_configuration_saving_error_total', aggregators);

{
  successfulReloads:: successfulReloads,
  reloadFailures:: reloadFailures,
  successfulSaves:: successfulSaves,
  saveFailures:: saveFailures,
}
