local panels = import './panels.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local defaultSelector = 'environment=~"$environment", stage=~"$stage", shard=~"${shard:pipe}"';

local interpolationsRate(selector=defaultSelector) =
  panel.timeSeries(
    'Job inputs interpolations rate',
    description='Rate of CI/CD variable interpolation operations across job inputs.',
    legendFormat='{{shard}}',
    format='ops',
    query=|||
      sum by(shard) (
        rate(gitlab_runner_job_inputs_interpolations_total{%(selector)s}[$__rate_interval])
      )
    ||| % { selector: selector },
  );

local interpolationFailuresRate(selector=defaultSelector) =
  panel.timeSeries(
    'Job inputs interpolation failures rate',
    description='Rate of interpolation failures broken down by error type (parse_error, evaluation_error, unsupported_sensitive_value).',
    legendFormat='{{shard}} - {{error_type}}',
    format='ops',
    query=|||
      sum by(shard, error_type) (
        rate(gitlab_runner_job_inputs_interpolation_failures_total{%(selector)s}[$__rate_interval])
      )
    ||| % { selector: selector },
  );

local interpolationSuccessRate(selector=defaultSelector) =
  panel.timeSeries(
    'Job inputs interpolation success rate',
    legendFormat='{{shard}}',
    format='percentunit',
    query=|||
      1 - (
        sum by(shard) (
          rate(gitlab_runner_job_inputs_interpolation_failures_total{%(selector)s}[$__rate_interval])
        )
        /
        sum by(shard) (
          rate(gitlab_runner_job_inputs_interpolations_total{%(selector)s}[$__rate_interval])
        )
      )
    ||| % { selector: selector },
    description=|||
      Shows the percentage of successful interpolations.
      A value of 1 (100%) means no failures occurred.
      This metric helps identify if error rates are increasing or decreasing over time.
    |||,
  );

local interpolationFailuresPieChart(selector=defaultSelector) =
  panels.pieChart(
    'Interpolation failures by type',
    query=|||
      sum by(error_type) (
        increase(
          gitlab_runner_job_inputs_interpolation_failures_total{%(selector)s}[$__range]
        )
      )
    ||| % { selector: selector },
    legendFormat='{{error_type}}',
    instant=true,
    description=|||
      Distribution of interpolation failure types:
      - parse_error: Failed to parse the interpolation expression
      - evaluation_error: Failed to evaluate the expression
      - unsupported_sensitive_value: Attempted to use a sensitive value in an unsupported context
    |||,
  );

local interpolationsCounter(selector=defaultSelector) =
  basic.statPanel(
    title=null,
    panelTitle='Total interpolations',
    color='green',
    description='Total count of interpolation operations across all runner managers over the dashboard time range.',
    query=|||
      sum by(shard) (
        increase(
          gitlab_runner_job_inputs_interpolations_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
    legendFormat='{{shard}}',
    unit='short',
    decimals=0,
    colorMode='value',
    instant=false,
    interval='1d',
    intervalFactor=1,
    reducerFunction='sum',
    justifyMode='center',
  );

{
  defaultSelector:: defaultSelector,
  interpolationsRate:: interpolationsRate,
  interpolationFailuresRate:: interpolationFailuresRate,
  interpolationSuccessRate:: interpolationSuccessRate,
  interpolationFailuresPieChart:: interpolationFailuresPieChart,
  interpolationsCounter:: interpolationsCounter,
}
