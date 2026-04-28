local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'runbooks/libsonnet/grafana/basic.libsonnet';
local panel = import 'runbooks/libsonnet/grafana/time-series/panel.libsonnet';
local selectors = import 'runbooks/libsonnet/promql/selectors.libsonnet';

local uptimeQuery(selector, range='$__range', interval='1m') =
  |||
    sum_over_time(
      (
        gitlab_component_ops:rate_1h{%(selector)s, component="api_requests"}
        -
        gitlab_component_errors:rate_1h{%(selector)s, component="api_requests"}
      )[%(range)s:%(interval)s]
    )
    /
    sum_over_time(
      gitlab_component_ops:rate_1h{%(selector)s, component="api_requests"}[%(range)s:%(interval)s]
    )
  ||| % { selector: selector, range: range, interval: interval };

local totalOfflineHoursQuery(selector, range='$__range', interval='1m') =
  |||
    (
        1 -
        (
          (
            sum_over_time(sum(gitlab_component_ops:rate_1h{%(selector)s, component="api_requests"})[%(range)s:%(interval)s])
            -
            sum_over_time(sum(gitlab_component_errors:rate_1h{%(selector)s, component="api_requests"})[%(range)s:%(interval)s])
          )
          /
          sum_over_time(sum(gitlab_component_ops:rate_1h{%(selector)s, component="api_requests"})[%(range)s:%(interval)s])
        )
      ) * ($__range_s / 3600)
  ||| % { selector: selector, range: range, interval: interval };

local downtimeHoursQuery(selector, range='$__range', interval='1m') =
  |||
    last_over_time(
      (
        (
          (
            (sum(gitlab_component_ops:rate_1h{%(selector)s, component="api_requests"}) OR on() vector(0))
            -
            (sum(gitlab_component_errors:rate_1h{%(selector)s, component="api_requests"}) OR on() vector(0))
          ) > bool 0
        )
      )[%(range)s:%(interval)s]
    )
  ||| % { selector: selector, range: range, interval: interval };

local availabilityQuery(selector, range='$__range', interval='1m') =
  |||
    sum_over_time(sum by(component) (
      gitlab_service_ops:rate_1h{%(selector)s, component="ci_runner_jobs"} -  gitlab_service_errors:rate_1h{%(selector)s, component="ci_runner_jobs"}
    )[%(range)s:%(interval)s])
    /
    sum_over_time(
      sum by(component) (
        gitlab_service_ops:rate_1h{%(selector)s, component="ci_runner_jobs"}
      )[%(range)s:%(interval)s])
  ||| % { selector: selector, range: range, interval: interval };

local queuingViolationsQuery(selector, range='$__range', interval='1m') =
  |||
    sum(sum_over_time(
      (
        (
          sum by (shard) (
            increase(
              (
                sum by (shard) (gitlab_runner_acceptable_job_queuing_duration_exceeded_total{type="hosted-runners"})
              )[1m:1m]
            )
          ) or (
            0 * sum by (shard) (gitlab_runner_acceptable_job_queuing_duration_exceeded_total{type="hosted-runners"})
          )
        ) *
        (
          min_over_time(
            (sum by(shard)(fleeting_provisioner_instances{%(selector)s, state!="deleting"}) < bool sum by(shard)(fleeting_provisioner_max_instances) * .9)[2m:1m]
          )
        )
      )[%(range)s:%(interval)s]
    ))
  ||| % { selector: selector, range: range, interval: interval };

local jobQueuingSLOQuery(selector, range='$__range', interval='1m') =
  |||
    1 -
    %(violations)s /
    increase(sum(gitlab_runner_jobs_total{%(selector)s})[%(range)s:%(interval)s])
  ||| % {
    selector: selector,
    range: range,
    interval: interval,
    violations: queuingViolationsQuery(selector, range, interval),
  };

local sloColorScheme = [
  { color: 'red', value: null },
  { color: 'light-red', value: 0.95 },
  { color: 'orange', value: 0.99 },
  { color: 'light-orange', value: 0.995 },
  { color: 'yellow', value: 0.9994 },
  { color: 'light-yellow', value: 0.9995 },
  { color: 'green', value: 0.9998 },
];

local uptimeColorSchema = [
  { color: 'green', value: null },
  { color: 'red', value: 0.1 },
];

local overallAvailability(selector) =
  basic.statPanel(
    title='',
    panelTitle='Job Successful Rate',
    description="Percentage of ci_runner_jobs over the dashboard's range that did not have internal errors.",
    query=availabilityQuery(selector),
    unit='percentunit',
    min=0,
    max=1,
    decimals=2,
    color=sloColorScheme,
    graphMode='none',
    stableId='hosted-runners-overall-availability',
  );

local budgetSpent(selector) =
  basic.statPanel(
    title='',
    panelTitle='Availability Budget Spent',
    description="Estimated time over the dashboard's period where ci_runner_jobs failed due to internal errors",
    query=|||
      (1 - (%(availability)s)) * $__range_ms
    ||| % { availability: availabilityQuery(selector) },
    unit='dtdurationms',
    min=0,
    decimals=0,
    color=sloColorScheme,
    graphMode='none',
    stableId='hosted-runners-budget-spent',
  );

local rollingAvailability(selector) =
  panel.timeSeries(
    title='Rolling availability',
    description="Percentage of ci_runner_jobs over the dashboard's range that did not have internal errors, looking back over the dashboard's range window.",
    query=availabilityQuery(selector, '$__range', '$__interval'),
    legendFormat='__auto',
    format='percentunit',
    min=0,
    max=1,
    fill=0,
    stableId='hosted-runners-rolling-availability'
  );

local jobQueuingSLO(selector) =
  basic.statPanel(
    title='',
    panelTitle='Job Queue Latency',
    description="Percentage of all jobs over the dashboard's range that were executed within an acceptable time. Excludes jobs that were delayed because the scaleMax threshold was hit.",
    query=jobQueuingSLOQuery(selector),
    unit='percentunit',
    min=0,
    max=1,
    decimals=2,
    color=sloColorScheme,
    graphMode='none',
    stableId='job-queuing-slo',
  );

local queuingViolationsCount(selector) =
  basic.statPanel(
    title='',
    panelTitle='Jobs Violating Latency',
    description="Number of jobs over the dashboard's range that exceeded the acceptable time. Excludes jobs that were delayed because the scaleMax threshold was hit.",
    query=queuingViolationsQuery(selector),
    unit='none',
    min=0,
    color='yellow',
    decimals=0,
    graphMode='none',
    stableId='job-queuing-violations-count',
  );

local jobQueuingSLOOverTime(selector) =
  panel.timeSeries(
    title='Job Queuing Latency SLO Over Time',
    description="Percentage of all jobs looking back over the dashboard's range that were executed within an acceptable time. Excludes jobs that were delayed because the scaleMax threshold was hit.",
    query=jobQueuingSLOQuery(selector, '$__range', '$__interval'),
    legendFormat='Job Queuing SLO',
    format='percentunit',
    min=0.9,
    max=1,
    fill=0,
    stableId='job-queuing-slo-over-time'
  );

local runnerUptimeSLO(selector) =
  basic.statPanel(
    title='',
    panelTitle='Runner Uptime Rate',
    description='Percentage of time the runner stayed online based on successful API heartbeats.',
    query=uptimeQuery(selector),
    unit='percentunit',
    min=0,
    max=1,
    decimals=2,
    color=sloColorScheme,
    graphMode='none',
    stableId='hosted-runners-uptime',
  );

local totalOfflineHours(selector, range='$__range', interval='1m') =
  basic.statPanel(
    title='',
    panelTitle='Availability Budget Spent',
    description='Total time the runner was offline during the selected period, based on missing API heartbeat signals.',
    query=totalOfflineHoursQuery(selector),
    unit='m',
    min=0,
    decimals=0,
    color=uptimeColorSchema,
    graphMode='none',
    stableId='hosted-runners-total-offline-hours',
  );

local downtimeHours(selector) =
  grafana.graphPanel.new(
    title='Runner Downtime',
  ) + {
    type: 'status-history',
    datasource: { type: 'prometheus', uid: '$PROMETHEUS_DS' },
    description: 'Hourly view of offline activity for the selected runner, showing when API heartbeats were missing and downtime occurred.',
    targets: [
      {
        refId: 'A',
        datasource: { type: 'prometheus', uid: '$PROMETHEUS_DS' },
        legendFormat: 'Status',
        expr: downtimeHoursQuery(selector),
        interval: '5m',
      },
    ],

    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        thresholds: {
          mode: 'absolute',
          steps: [{ color: 'green', value: null }],
        },
        mappings: [
          {
            type: 'value',
            options: {
              '0': { text: 'Offline', color: 'dark-red' },
              '1': { text: 'Online', color: 'dark-green' },
            },
          },
        ],
        custom: {
          lineWidth: 2,
          fillOpacity: 0,
        },
      },
      overrides: [],
    },
    options: {
      showValue: 'auto',
    },
    timeFrom: '24h',
  };


{
  new(selectorHash):: {
    local selector = selectors.serializeHash(selectorHash),

    overallAvailability:: overallAvailability(selector),
    budgetSpent:: budgetSpent(selector),
    rollingAvailability:: rollingAvailability(selector),
    jobQueuingSLO:: jobQueuingSLO(selector),
    queuingViolationsCount:: queuingViolationsCount(selector),
    jobQueuingSLOOverTime:: jobQueuingSLOOverTime(selector),
    runnerUptimeSLO:: runnerUptimeSLO(selector),
    totalOfflineHours:: totalOfflineHours(selector),
    downtimeHours:: downtimeHours(selector),
  },
}
