local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local keyMetrics = import 'gitlab-dashboards/key_metrics.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local aggregationSets = (import 'gitlab-metrics-config.libsonnet').aggregationSets;
local override = import 'grafana/time-series/override.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local text = grafana.text;


local headlineMetricsRow(
  serviceType,
  rowTitle='Hosted Runner(s) Overview',
  metricsCatalogServiceInfo,
  selectorHash,
  showSaturationCell,
  expectMultipleSeries=false,
      ) =
  local hasApdex = metricsCatalogServiceInfo.hasApdex();
  local hasErrorRate = metricsCatalogServiceInfo.hasErrorRate();
  local hasRequestRate = metricsCatalogServiceInfo.hasRequestRate();
  local selectorHashWithExtras = selectorHash { type: serviceType };

  keyMetrics.headlineMetricsRow(
    serviceType=serviceType,
    startRow=0,
    rowTitle=rowTitle,
    selectorHash=selectorHashWithExtras,
    stableIdPrefix='',
    showApdex=hasApdex,
    legendFormatPrefix='{{component}} - {{shard}}',
    showErrorRatio=hasErrorRate,
    showOpsRate=hasRequestRate,
    showSaturationCell=showSaturationCell,
    compact=false,
    rowHeight=10,
    aggregationSet=aggregationSets.shardComponentSLIs
  );

local notes(title='Notes', content) = text.new(
  title=title,
  mode='markdown',
  content=content
);

local table(title, query, description='', sortBy=[], transform_organize={}, transform_groupBy={}) = (
  panel.table(
    title=title,
    query=query,
    description=description,
    styles=null
  ) {
    options+: {
      sortBy: sortBy,
    },
    transformations: [
      {
        id: 'organize',
        options: transform_organize,
      },
      {
        id: 'groupBy',
        options: {
          fields: transform_groupBy,
        },
      },
    ],
  }
);

local versionsTable(selector) = table(
  title='GitLab Runner(s) Versions',
  description='Current GitLab Runner version for each runner manager instance, including OS, architecture, and Go version.',
  query=|||
    gitlab_runner_version_info{%(selector)s}
  ||| % { selector: selector },
  sortBy=[{
    desc: true,
    displayName: 'version',
  }],
  transform_organize={
    excludeByName: {
      Time: true,
      Value: true,
      __name__: true,
      branch: true,
      built_at: true,
      env: true,
      environment: true,
      fqdn: true,
      job: true,
      monitor: true,
      name: true,
      provider: true,
      region: true,
      stage: true,
      tier: true,
      type: true,
    },
    indexByName: {
      instance: 0,
      runner_id: 1,
      shard: 2,
      version: 3,
      instance_type: 4,
      os: 5,
      architecture: 6,
      go_version: 7,
      revision: 8,
    },
    renameByName: {
      architecture: 'arch',
      go_version: '',
      revision: '',
    },
  },
  transform_groupBy={
    instance: {
      aggregations: ['last'],
      operation: 'aggregate',
    },
  }
) + {
  fieldConfig+: {
    overrides+: [
      {
        matcher: { id: 'byName', options: 'instance' },
        properties: [{ id: 'custom.width', value: 200 }],
      },
      {
        matcher: { id: 'byName', options: 'version' },
        properties: [{ id: 'custom.width', value: 120 }],
      },
      {
        matcher: { id: 'byName', options: 'revision' },
        properties: [{ id: 'custom.width', value: 120 }, { id: 'filterable', value: false }],
      },
      {
        matcher: { id: 'byName', options: 'os' },
        properties: [{ id: 'custom.width', value: 80 }, { id: 'filterable', value: false }],
      },
      {
        matcher: { id: 'byName', options: 'arch' },
        properties: [{ id: 'custom.width', value: 80 }, { id: 'filterable', value: false }],
      },
      {
        matcher: { id: 'byName', options: 'go_version' },
        properties: [{ id: 'custom.width', value: 90 }, { id: 'filterable', value: false }],
      },
      {
        matcher: { id: 'byName', options: 'shard' },
        properties: [{ id: 'custom.width', value: 120 }],
      },
      {
        matcher: { id: 'byName', options: 'runner_id' },
        properties: [{ id: 'custom.width', value: 90 }],
      },
      {
        matcher: { id: 'byName', options: 'instance_type' },
        properties: [{ id: 'custom.width', value: 120 }],
      },
    ],
  },
};

local uptimeTable(selector) = table(
  'GitLab Runner(s) Uptime',
  description='Time elapsed since each runner manager process last started. Sorted ascending to surface recently restarted instances.',
  query=|||
    time() - process_start_time_seconds{%(selector)s}
  ||| % { selector: selector },
  sortBy=[{
    asc: true,
    displayName: 'Uptime (last)',
  }],
  transform_organize={
    excludeByName: {
      Time: true,
      env: true,
      environment: true,
      fqdn: true,
      job: true,
      monitor: true,
      provider: true,
      region: true,
      stage: true,
      tier: true,
      type: true,
    },
    indexByName: {
      instance: 0,
      Value: 1,
    },
    renameByName: {
      Value: 'Uptime',
    },
  },
  transform_groupBy={
    instance: {
      aggregations: [],
      operation: 'groupby',
    },
    Uptime: {
      aggregations: ['last'],
      operation: 'aggregate',
    },
  }
) + {
  fieldConfig+: {
    defaults+: {
      unit: 's',
    },
    overrides+: [
      {
        matcher: { id: 'byName', options: 'instance' },
        properties: [{ id: 'custom.width', value: null }],
      },
      {
        matcher: { id: 'byName', options: 'Uptime (last)' },
        properties: [{ id: 'custom.width', value: 120 }],
      },
    ],
  },
};

local statPanel(
  panelTitle,
  description='',
  query,
  color='blue'
      ) =
  basic.statPanel(
    title=null,
    panelTitle=panelTitle,
    description=description,
    query=query,
    legendFormat='{{shard}}',
    unit='short',
    decimals=0,
    colorMode='value',
    instant=true,
    interval='1d',
    intervalFactor=1,
    reducerFunction='last',
    justifyMode='center',
    color=color,
  );

local hostedRunnerSaturation(selector) =
  panel.timeSeries(
    title='Runner saturation of concurrent',
    description='Saturation from the recording rule gitlab_component_saturation:ratio, with soft (85%) and hard (95%) SLO thresholds.',
    legendFormat='{{ shard }} jobs running',
    linewidth=2,
    format='percentunit',
    yAxisLabel='Saturation %',
    min=0,
    query=|||
      gitlab_component_saturation:ratio{type="hosted-runners", %(selector)s}
    ||| % { selector: selector }
  ).addTarget(
    target.prometheus(
      expr='0.85',
      legendFormat='Soft SLO',
    )
  ).addTarget(
    target.prometheus(
      expr='0.95',
      legendFormat='Hard SLO',
    )
  ).addSeriesOverride({
    alias: '/.*SLO$/',
    color: '#F2495C',
    stack: false,
    dashes: true,
    linewidth: 4,
    dashLength: 4,
    spaceLength: 4,
  });

local totalApiRequests(selector) =
  panel.timeSeries(
    title='Total number of api requests',
    description='Rate of all API calls from gitlab-runner to GitLab, broken down by endpoint, status code, and shard.',
    query=|||
      sum by(status, shard, endpoint) (
        increase(
          gitlab_runner_api_request_statuses_total{%(selector)s} [$__rate_interval]
        )
      )
    ||| % { selector: selector },
    legendFormat='{{shard}} : api {{endpoint}} : status {{status}}',
    yAxisLabel='Api requests',
    drawStyle=''
  );

local runningJobs(selector) =
  panel.timeSeries(
    title='Jobs',
    description='Current number of running jobs per shard.',
    yAxisLabel='Running jobs',
    query=|||
      sum by (shard) (
        gitlab_runner_jobs{%(selector)s}
      )
    ||| % { selector: selector },
    legendFormat='{{shard}}',
  );

local runningJobPhase(selector) =
  panel.timeSeries(
    title='Running jobs phase',
    description='Distribution of currently running jobs by executor stage (prepare, build, cleanup, etc.)',
    yAxisLabel='Running jobs',
    query=|||
      sum by (executor_stage, stage, shard) (
        gitlab_runner_jobs{state="running", %(selector)s}
      )
    ||| % { selector: selector },
    legendFormat='{{shard}} : {{executor_stage}} : {{stage}}',
    drawStyle='bars',
  );

local runnerCaughtErrors(selector) =
  panel.timeSeries(
    title='Runner Manager Caught Errors',
    description='Rate of errors caught by the runner manager process itself (not job failures), broken down by log level.',
    yAxisLabel='Erros',
    query=|||
      sum (
        rate(
          gitlab_runner_errors_total{%(selector)s} [$__rate_interval]
        )
      ) by (level, shard)
    ||| % { selector: selector },
    legendFormat='{{shard}}: {{level}}',
    drawStyle='bars',
  );

local statusPanel(title='Status', legendFormat='', query, valueMapping, allValues=false, textMode='auto', description='') =
  basic.statPanel(
    title=null,
    panelTitle=title,
    color='',
    query=query,
    allValues=allValues,
    reducerFunction='lastNotNull',
    graphMode='none',
    colorMode='background',
    justifyMode='auto',
    thresholdsMode='absolute',
    unit='none',
    orientation='vertical',
    mappings=valueMapping,
    legendFormat=legendFormat,
    textMode=textMode,
    description=description,
  );


local ciPendingBuilds() =
  panel.timeSeries(
    title='Global count of pending builds',
    description='ci_pending_builds is a global metric across the entire GitLab instance — it is not filtered by runner, shard, or stack. Shows the total number of CI builds waiting for a runner (where shared_runners="no").',
    query=|||
      sum(ci_pending_builds{shared_runners="no"})
    |||,
    legendFormat='pending builds',
    yAxisLabel='Pending Builds',
    drawStyle='bars',
  );

local averageDurationOfQueuing(selector) =
  panel.timeSeries(
    title='Average duration of queuing',
    description='Average time jobs spend waiting in the queue before a runner picks them up, per shard. Hard SLO is 120 s (2 min). A rising trend indicates insufficient runner capacity.',
    legendFormat='{{shard}}',
    linewidth=2,
    format='s',
    fill=0,
    min=0,
    query=|||
      sum by (shard) (
        rate(gitlab_runner_job_queue_duration_seconds_sum{%(selector)s}[5m])
      )
      /
      sum by (shard) (
        gitlab_component_shard_ops:rate_5m{component="pending_builds", %(selector)s}
      )
    ||| % { selector: selector }
  ).addTarget(
    target.prometheus(
      expr='120',
      legendFormat='Hard SLO',
    )
  ).addSeriesOverride({
    alias: '/.*SLO$/',
    color: '#F2495C',
    dashes: true,
    legend: true,
    lines: true,
    linewidth: 2,
    dashLength: 4,
    spaceLength: 4,
  });

local differentQueuingPhase() =
  panel.timeSeries(
    title='Rate of builds queue operations',
    description='Rate of CI build queue operations (push, pop, etc.) across the GitLab instance. A growing gap between push and pop rates means jobs are accumulating faster than runners can consume them.',
    legendFormat='queuing operation {{ operation }}',
    linewidth=2,
    yAxisLabel='Rate per second',
    query=|||
      sum(
        rate(
          gitlab_ci_queue_operations_total{}[$__interval]
        )
      ) by (operation)
    |||
  );


local pollingRPS() =
  panel.timeSeries(
    title='Polling RPS - Overall',
    description='Overall rate of runner polling requests across all hosted-runner shards. A sustained drop typically means runners have stopped polling — check connectivity and authentication.',
    legendFormat='overall',
    linewidth=2,
    yAxisLabel='Requests per second',
    query=|||
      sum by () (
        gitlab_component_shard_ops:rate_5m{component="polling", type="hosted-runners"}
      )
    |||
  );

local pollingError() =
  panel.timeSeries(
    title='Polling Error - Overall',
    description='Overall rate of errors returned on runner polling requests. Sustained non-zero values indicate a connectivity, token, or GitLab availability problem.',
    legendFormat='overall',
    linewidth=2,
    yAxisLabel='Errors',
    query=|||
      sum by () (
        gitlab_component_shard_errors:rate_5m{component="polling", type="hosted-runners"}
      )
    |||
  );

// runnerSaturation: custom saturation panel for hosted runners.
// Uses the hosted-runners-specific job label and computes saturation as
// running_jobs / concurrent (or limit), with soft/hard SLO thresholds.
// Moved here from verify_runner_adapter.libsonnet because it uses different
// job label selectors than the upstream verify-runner saturation panels.
local runnerSaturation(aggregators, saturationType, selector) =
  local jobSaturationMetrics = {
    concurrent: 'gitlab_runner_concurrent',
    limit: 'gitlab_runner_limit',
  };
  local aggregatorLabel = std.join(', ', aggregators);
  local legendFormat = std.join(' - ', ['{{ %s }}' % a for a in aggregators]);
  panel.timeSeries(
    title='Runner saturation of %(type)s by %(agg)s' % { agg: aggregatorLabel, type: saturationType },
    description='Ratio of running jobs to the %(type)s ceiling per %(agg)s, with soft (85%%) and hard (90%%) SLO thresholds. Values approaching 100%% indicate the shard is near capacity.' % { agg: aggregatorLabel, type: saturationType },
    legendFormat=legendFormat,
    format='percentunit',
    query=|||
      (
        sum by (%(agg)s) (
          gitlab_runner_jobs{job="hosted-runners-prometheus-agent", %(sel)s}
        )
        /
        (
          sum by (%(agg)s) (
            %(maxMetric)s{job="hosted-runners-prometheus-agent", %(sel)s}
          ) > 0
        )
      )
      or
      (
        0 * sum by (%(agg)s) (
          gitlab_runner_version_info{%(sel)s}
        )
      )
    ||| % {
      agg: aggregatorLabel,
      maxMetric: jobSaturationMetrics[saturationType],
      sel: selector,
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

{
  headlineMetricsRow:: headlineMetricsRow,
  notes:: notes,
  versionsTable:: versionsTable,
  uptimeTable:: uptimeTable,
  statPanel:: statPanel,
  hostedRunnerSaturation:: hostedRunnerSaturation,
  totalApiRequests:: totalApiRequests,
  runningJobs:: runningJobs,
  runningJobPhase:: runningJobPhase,
  runnerCaughtErrors:: runnerCaughtErrors,
  ciPendingBuilds:: ciPendingBuilds,
  averageDurationOfQueuing:: averageDurationOfQueuing,
  differentQueuingPhase:: differentQueuingPhase,
  statusPanel:: statusPanel,
  pollingRPS:: pollingRPS,
  pollingError:: pollingError,
  runnerSaturation:: runnerSaturation,
}
