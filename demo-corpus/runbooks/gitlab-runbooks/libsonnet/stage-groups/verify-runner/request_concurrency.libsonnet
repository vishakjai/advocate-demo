local g = import 'github.com/grafana/grafonnet/gen/grafonnet-latest/main.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local ts = g.panel.timeSeries;

local defaultSelector = 'environment=~"$environment", stage=~"$stage", shard=~"${shard:pipe}"';

local limitsAndInFlight(selector=defaultSelector) =
  panel.multiTimeSeries(
    title='Request concurrency',
    description='Hard limit (absolute ceiling), adaptive limit (dynamically adjusted), used limit (currently enforced), and actual requests in flight. In-flight should stay below the adaptive limit during normal operation.',
    format='short',
    linewidth=1,
    queries=[
      {
        query: |||
          sum by (shard) (
            gitlab_runner_request_concurrency_hard_limit{%(selector)s}
          )
        ||| % { selector: selector },
        legendFormat: '{{shard}} hard limit',
      },
      {
        query: |||
          sum by (shard) (
            gitlab_runner_request_concurrency_adaptive_limit{%(selector)s}
          )
        ||| % { selector: selector },
        legendFormat: '{{shard}} adaptive limit',
      },
      {
        query: |||
          sum by (shard) (
            gitlab_runner_request_concurrency_used_limit{%(selector)s}
          )
        ||| % { selector: selector },
        legendFormat: '{{shard}} used limit',
      },
      {
        query: |||
          sum by (shard) (
            gitlab_runner_request_concurrency{%(selector)s}
          )
        ||| % { selector: selector },
        legendFormat: '{{shard}} requests in flight',
      },
    ]
  )
  + ts.standardOptions.withOverridesMixin({
    matcher: {
      id: 'byRegexp',
      options: '/hard limit/',
    },
    properties: [
      {
        id: 'custom.lineWidth',
        value: 3,
      },
      {
        id: 'color',
        value: {
          mode: 'fixed',
          fixedColor: 'red',
        },
      },
    ],
  })
  + ts.standardOptions.withOverridesMixin({
    matcher: {
      id: 'byRegexp',
      options: '/adaptive limit/',
    },
    properties: [
      {
        id: 'custom.lineWidth',
        value: 2,
      },
      {
        id: 'color',
        value: {
          mode: 'fixed',
          fixedColor: 'orange',
        },
      },
    ],
  })
  + ts.standardOptions.withOverridesMixin({
    matcher: {
      id: 'byRegexp',
      options: '/used limit/',
    },
    properties: [
      {
        id: 'custom.lineWidth',
        value: 2,
      },
      {
        id: 'color',
        value: {
          mode: 'fixed',
          fixedColor: 'yellow',
        },
      },
    ],
  })
  + ts.standardOptions.withOverridesMixin({
    matcher: {
      id: 'byRegexp',
      options: '/requests in flight/',
    },
    properties: [
      {
        id: 'custom.lineWidth',
        value: 1,
      },
      {
        id: 'color',
        value: {
          mode: 'fixed',
          fixedColor: 'green',
        },
      },
    ],
  })
;

local exceeded(selector=defaultSelector) =
  panel.timeSeries(
    title='Request concurrency exceeded',
    description='Count of times the request concurrency limit was hit, causing a request to wait or be dropped. Sustained non-zero values mean the runner is rate-limited on job polling.',
    legendFormat='{{shard}} exceeded',
    format='short',
    linewidth=2,
    query=|||
      sum by (shard) (
        increase(
          gitlab_runner_request_concurrency_exceeded_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

{
  defaultSelector:: defaultSelector,
  limitsAndInFlight:: limitsAndInFlight,
  exceeded:: exceeded,
}
