local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local errorBudget = import 'stage-groups/error_budget.libsonnet';
local row = grafana.row;
local text = grafana.text;

local baseSelector = { environment: '$environment', stage: '$stage' };
local baseSelectorRegex = { environment: { re: '$environment' }, stage: { re: '$stage' } };
local selector = selectors.serializeHash(baseSelector);
local selectorWithEnv = selectors.serializeHash(baseSelector { env: '$environment' });
local selectorWithMonitor = selectors.serializeHash(baseSelector { env: '$environment', monitor: 'global' });
local selectorRunnerRegex = selectors.serializeHash(baseSelectorRegex);

local budget = errorBudget('$__range');

local jobSystemFailureReasons = 'stuck_or_timeout_failure|stale_schedule|runner_system_failure|scheduler_failure|data_integrity_failure|environment_creation_failure|job_router_failure';
local jobNonInfraFailureReasons = 'script_failure|ci_quota_exceeded|builds_disabled|user_blocked|stale_schedule|forward_deployment_failure|failed_outdated_deployment_job|api_failure|downstream_pipeline_creation_failed|downstream_bridge_project_not_found|insufficient_bridge_permissions|protected_environment_failure|no_matching_runner|runner_unsupported|secrets_provider_not_found|ip_restriction_failure|deployment_rejected|duo_workflow_not_allowed|invalid_bridge_trigger|job_token_expired|pipeline_loop_detected|reached_max_descendant_pipelines_depth|trace_size_exceeded|unmet_prerequisites|upstream_bridge_project_not_found|job_execution_timeout|missing_dependency_failure';

local runnerIcon = '🏃‍♂️ ';

local pipelineCreationWorkers = '.*CreatePipelineWorker.*';
local pipelineProcessingWorkers = 'Ci::InitialPipelineProcessWorker|PipelineProcessWorker|Ci::BuildFinishedWorker|BuildQueueWorker';

local sidekiqQueueApdexPanel(title, workerRegex, links=[], description='') =
  panel.basic(
    title,
    linewidth=2,
    unit='percentunit',
    description=description,
  )
  .addTarget(
    target.prometheus(
      'clamp_min(clamp_max(sum(sli_aggregations:gitlab_sli_sidekiq_queueing_apdex_success_total:rate_5m{%(sel)s,worker=~"%(w)s"}) / sum(sli_aggregations:gitlab_sli_sidekiq_queueing_apdex_total:rate_5m{%(sel)s,worker=~"%(w)s"}), 1), 0)' % { sel: selectorWithEnv, w: workerRegex },
      legendFormat='queue apdex',
    )
  )
  .addTarget(
    target.prometheus(
      '(1 - 6 * (1 - avg(slo:min:events:gitlab_service_apdex:ratio{component="sidekiq_queueing",type="sidekiq",monitor="global"})))',
      legendFormat='6h Degradation SLO (5% of monthly error budget)',
      interval='5m',
    )
  )
  .addTarget(
    target.prometheus(
      '(1 - 14.4 * (1 - avg(slo:min:events:gitlab_service_apdex:ratio{component="sidekiq_queueing",type="sidekiq",monitor="global"})))',
      legendFormat='1h Outage SLO (2% of monthly error budget)',
      interval='5m',
    )
  )
  .addTarget(
    target.prometheus(
      'clamp_min(clamp_max(sum(sli_aggregations:gitlab_sli_sidekiq_queueing_apdex_success_total:rate_5m{%(sel)s,worker=~"%(w)s"} offset 1w) / sum(sli_aggregations:gitlab_sli_sidekiq_queueing_apdex_total:rate_5m{%(sel)s,worker=~"%(w)s"} offset 1w), 1), 0)' % { sel: selectorWithEnv, w: workerRegex },
      legendFormat='last week',
    )
  )
  .addYaxis(max=1)
  .addSeriesOverride({ alias: '/6h Degradation SLO.*/', dashes: true, dashLength: 4, color: '#FF4500', linewidth: 2 })
  .addSeriesOverride({ alias: '/1h Outage SLO.*/', dashes: true, dashLength: 4, color: '#F2495C', linewidth: 4 })
  .addSeriesOverride({ alias: 'last week', dashes: true, dashLength: 4, color: '#dddddd80', linewidth: 1 })
  .addSeriesOverride({ alias: 'queue apdex', color: '#E7D551' })
  + { links: links };

local sidekiqExecApdexPanel(title, workerRegex, links=[], description='') =
  panel.basic(
    title,
    linewidth=2,
    unit='percentunit',
    description=description,
  )
  .addTarget(
    target.prometheus(
      'clamp_min(clamp_max(sum(sli_aggregations:gitlab_sli_sidekiq_execution_apdex_success_total:rate_5m{%(sel)s,worker=~"%(w)s"}) / sum(sli_aggregations:gitlab_sli_sidekiq_execution_apdex_total:rate_5m{%(sel)s,worker=~"%(w)s"}), 1), 0)' % { sel: selectorWithEnv, w: workerRegex },
      legendFormat='execution apdex',
    )
  )
  .addTarget(
    target.prometheus(
      '(1 - 6 * (1 - avg(slo:min:events:gitlab_service_apdex:ratio{component="sidekiq_execution",type="sidekiq",monitor="global"})))',
      legendFormat='6h Degradation SLO (5% of monthly error budget)',
      interval='5m',
    )
  )
  .addTarget(
    target.prometheus(
      '(1 - 14.4 * (1 - avg(slo:min:events:gitlab_service_apdex:ratio{component="sidekiq_execution",type="sidekiq",monitor="global"})))',
      legendFormat='1h Outage SLO (2% of monthly error budget)',
      interval='5m',
    )
  )
  .addTarget(
    target.prometheus(
      'clamp_min(clamp_max(sum(sli_aggregations:gitlab_sli_sidekiq_execution_apdex_success_total:rate_5m{%(sel)s,worker=~"%(w)s"} offset 1w) / sum(sli_aggregations:gitlab_sli_sidekiq_execution_apdex_total:rate_5m{%(sel)s,worker=~"%(w)s"} offset 1w), 1), 0)' % { sel: selectorWithEnv, w: workerRegex },
      legendFormat='last week',
    )
  )
  .addYaxis(max=1)
  .addSeriesOverride({ alias: '/6h Degradation SLO.*/', dashes: true, dashLength: 4, color: '#FF4500', linewidth: 2 })
  .addSeriesOverride({ alias: '/1h Outage SLO.*/', dashes: true, dashLength: 4, color: '#F2495C', linewidth: 4 })
  .addSeriesOverride({ alias: 'last week', dashes: true, dashLength: 4, color: '#dddddd80', linewidth: 1 })
  .addSeriesOverride({ alias: 'execution apdex', color: '#E7D551' })
  + { links: links };

local sidekiqSuccessRatePanel(title, workerRegex, description='') =
  panel.basic(
    title,
    linewidth=2,
    unit='percentunit',
    description=description,
  )
  .addTarget(
    target.prometheus(
      'clamp_min(clamp_max(1 - (sum(sli_aggregations:gitlab_sli_sidekiq_execution_error_total:rate_5m{%(sel)s,worker=~"%(w)s"}) / (sum(sli_aggregations:gitlab_sli_sidekiq_execution_total:rate_5m{%(sel)s,worker=~"%(w)s"}) > 0)), 1), 0)' % { sel: selectorWithEnv, w: workerRegex },
      legendFormat='success rate',
    )
  )
  .addTarget(
    target.prometheus(
      '(1 - 6 * (1 - avg(slo:min:events:gitlab_service_apdex:ratio{component="sidekiq_execution",type="sidekiq",monitor="global"})))',
      legendFormat='6h Degradation SLO (5% of monthly error budget)',
      interval='5m',
    )
  )
  .addTarget(
    target.prometheus(
      '(1 - 14.4 * (1 - avg(slo:min:events:gitlab_service_apdex:ratio{component="sidekiq_execution",type="sidekiq",monitor="global"})))',
      legendFormat='1h Outage SLO (2% of monthly error budget)',
      interval='5m',
    )
  )
  .addYaxis(max=1)
  .addSeriesOverride({ alias: '/6h Degradation SLO.*/', dashes: true, dashLength: 4, color: '#FF4500', linewidth: 2 })
  .addSeriesOverride({ alias: '/1h Outage SLO.*/', dashes: true, dashLength: 4, color: '#F2495C', linewidth: 4 })
  .addSeriesOverride({ alias: 'success rate', color: '#E7D551' });

local sidekiqDbDurationPanel(title, workerRegex, description='') =
  panel.basic(
    title,
    linewidth=1,
    unit='s',
    description=description,
    thresholdSteps=[
      { value: null, color: 'transparent' },
      { value: 2, color: '#EAB839' },
      { value: 5, color: 'red' },
    ],
  )
  .addTarget(
    target.prometheus(
      'sum by (queue,worker)(rate(sidekiq_jobs_db_seconds_sum{%(sel)s,worker=~"%(w)s"}[$__interval])) / sum by (queue,worker)(rate(sidekiq_jobs_completion_count{%(sel)s,worker=~"%(w)s"}[$__interval]))' % { sel: selectorWithEnv, w: workerRegex },
      legendFormat='{{worker}}: {{queue}}',
      interval='5m',
    )
  )
  .addYaxis(min=0)
  + {
    fieldConfig+: {
      defaults+: {
        color: { mode: 'palette-classic' },
        custom+: {
          thresholdsStyle: { mode: 'dashed+area' },
        },
      },
    },
  };

local queueDurationStatPanel(title, sharedRunner, percentile, transparent=false, description='') =
  local pStr = if percentile == 0.5 then 'p50' else 'p90';
  local baseQuery = 'histogram_quantile(%(p)s, sum by (le)(sum_over_time(sli_aggregations:job_queue_duration_seconds_bucket:rate_5m{%(sel)s,shared_runner="%(sr)s"}[$__range])))' % { p: percentile, sel: selectorWithEnv, sr: sharedRunner };
  local trendQuery(offset) = '(%(base)s - (%(base_offset)s)) / (%(base_offset)s)' % { base: baseQuery, base_offset: std.strReplace(baseQuery, '[$__range]', '[$__range] offset %(offset)s' % { offset: offset }) };
  basic.statPanel(
    title=pStr,
    panelTitle=title,
    description=description,
    colorMode='value',
    legendFormat=pStr,
    color=[
      { color: 'green', value: 0 },
      { color: 'yellow', value: if sharedRunner == 'true' then 0.75 else (if percentile == 0.9 then 25 else 0.75) },
      { color: 'red', value: if sharedRunner == 'true' then 1 else (if percentile == 0.9 then 30 else 1) },
    ],
    query=baseQuery,
    unit='s',
    decimals=1,
    min=0,
    instant=true,
  ) + {
    transparent: transparent,
    targets+: [
      promQuery.target(
        trendQuery('1d'),
        legendFormat='trend 1d',
        instant=true,
      ),
      promQuery.target(
        trendQuery('7d'),
        legendFormat='trend 7d',
        instant=true,
      ),
    ],
    fieldConfig+: {
      defaults+: {
        displayName: '',
      },
      overrides+: [
        {
          matcher: { id: 'byRegexp', options: '/trend.*/' },
          properties: [
            { id: 'unit', value: 'percentunit' },
            {
              id: 'thresholds',
              value: {
                mode: 'absolute',
                steps: [
                  { color: 'green', value: null },
                  { color: 'yellow', value: 0 },
                  { color: 'red', value: 0.25 },
                ],
              },
            },
          ],
        },
      ],
    },
  };


local stageGroups = [
  { name: 'pipeline_authoring', title: 'Pipeline Authoring', link: 'https://dashboards.gitlab.net/d/stage-groups-pipeline_authoring/168421b' },
  { name: 'pipeline_execution', title: 'Pipeline Execution', link: 'https://dashboards.gitlab.net/d/stage-groups-pipeline_execution/c791104' },
  { name: 'ci_platform', title: 'CI Platform', link: 'https://dashboards.gitlab.net/d/stage-groups-ci_platform/stage-groups3a-ci-platform3a-group-dashboard' },
  { name: 'gitaly', title: 'Gitaly', link: 'https://dashboards.gitlab.net/d/stage-groups-gitaly/stage-groups3a-gitaly3a-group-dashboard' },
];

basic.dashboard(
  'Pipeline Observability',
  tags=['type:ci-orchestration'],
  time_from='now-6h/m',
  time_to='now',
)
.addTemplate(templates.stage)
.addPanels(
  std.flattenArrays([
    [
      budget.panels.availabilityStatPanel(sg.name) {
        title: sg.title + ' availability',
        links: [{ title: sg.title + ' Group dashboard', url: sg.link }],
        gridPos: { x: i * 4, y: 0, w: 4, h: 4 },
      },
    ]
    for i in std.range(0, std.length(stageGroups) - 1)
    for sg in [stageGroups[i]]
  ])
  +
  [
    budget.panels.explanationPanel('the respective team') {
      gridPos: { x: 16, y: 0, w: 8, h: 7 },
    },
  ]
  +
  std.flattenArrays([
    [
      budget.panels.errorBudgetStatusPanel(sg.name) {
        gridPos: { x: i * 4, y: 4, w: 4, h: 2 },
      },
    ]
    for i in std.range(0, std.length(stageGroups) - 1)
    for sg in [stageGroups[i]]
  ])
  +
  [
    budget.panels.availabilityTargetStatPanel(sg.name) {
      gridPos: { x: i * 4, y: 6, w: 4, h: 1 },
    }
    for i in std.range(0, std.length(stageGroups) - 1)
    for sg in [stageGroups[i]]
  ]
  +
  [
    basic.statPanel(
      title='',
      panelTitle='Created pipelines',
      description='Pipelines created during the period',
      color='green',
      query='sum(increase(pipelines_created_total{%(sel)s}[$__range]))' % { sel: selectorWithEnv },
      unit='short',
      min=0,
      instant=true,
      colorMode='value',
      graphMode='none',
      links=[{ title: 'Pipeline Authoring dashboard', url: 'https://dashboards.gitlab.net/d/stage-groups-pipeline_authoring/168421b' }],
    ) { gridPos: { x: 0, y: 7, w: 3, h: 10 } },

    basic.statPanel(
      title='',
      panelTitle='7-Day Trend (% change)',
      description='Percentage change in total pipelines created over the last 7 days vs the prior 7 days. Stable is within ±10%. Gradual growth is expected as platform usage increases.',
      color=[
        { color: 'red', value: 0 },
      ],
      query='(sum(sum_over_time(sli_aggregations:pipelines_created_total:rate_5m{%(sel)s}[7d])) - sum(sum_over_time(sli_aggregations:pipelines_created_total:rate_5m{%(sel)s}[7d] offset 7d))) / sum(sum_over_time(sli_aggregations:pipelines_created_total:rate_5m{%(sel)s}[7d] offset 7d))' % { sel: selectorWithEnv },
      unit='percentunit',
      decimals=1,
      instant=true,
      colorMode='value',
    ) {
      gridPos: { x: 3, y: 7, w: 3, h: 5 },
      fieldConfig+: {
        defaults+: {
          color: { mode: 'palette-classic' },
        },
        overrides+: [
          {
            matcher: { id: 'byValue', options: { op: 'lt', reducer: 'lastNotNull', value: 0 } },
            properties: [{ id: 'color' }],
          },
        ],
      },
    },

    queueDurationStatPanel('Shared runners: Job queue duration', 'true', 0.5, transparent=true, description='Median (p50) job queue wait time for GitLab-managed (shared) runners over the dashboard time range. Healthy baseline: < 1s. A rising p50 means most jobs are waiting longer, not just a long tail.') {
      gridPos: { x: 6, y: 7, w: 5, h: 5 },
    },

    queueDurationStatPanel('Self-managed runners: Job queue duration', 'false', 0.5, transparent=true, description='Median (p50) job queue wait time for self-managed (project/group) runners over the dashboard time range. Baselines vary by fleet size and configuration.') {
      gridPos: { x: 11, y: 7, w: 5, h: 5 },
    },

    basic.statPanel(
      title='',
      panelTitle='30-Day Trend (% change)',
      description='Percentage change in total pipelines created over the last 30 days vs the prior 30 days. Stable is within ±10%. Useful for spotting longer-term adoption trends or sustained regressions.',
      color=[
        { color: 'red', value: 0 },
      ],
      query='(sum(sum_over_time(sli_aggregations:pipelines_created_total:rate_5m{%(sel)s}[30d])) - sum(sum_over_time(sli_aggregations:pipelines_created_total:rate_5m{%(sel)s}[30d] offset 30d))) / sum(sum_over_time(sli_aggregations:pipelines_created_total:rate_5m{%(sel)s}[30d] offset 30d))' % { sel: selectorWithEnv },
      unit='percentunit',
      decimals=1,
      instant=true,
      colorMode='value',
    ) {
      gridPos: { x: 3, y: 12, w: 3, h: 5 },
      fieldConfig+: {
        defaults+: {
          color: { mode: 'palette-classic' },
        },
        overrides+: [
          {
            matcher: { id: 'byValue', options: { op: 'lt', reducer: 'lastNotNull', value: 0 } },
            properties: [{ id: 'color' }],
          },
        ],
      },
    },

    queueDurationStatPanel('', 'true', 0.9, transparent=true, description='90th percentile job queue wait time for GitLab-managed (shared) runners over the dashboard time range. Healthy baseline: 20–80s. Spikes indicate capacity pressure, autoscaling lag, or tag mismatches affecting a subset of jobs.') {
      gridPos: { x: 6, y: 12, w: 5, h: 5 },
    },

    queueDurationStatPanel('', 'false', 0.9, transparent=true, description='90th percentile job queue wait time for self-managed (project/group) runners over the dashboard time range. Large gaps between p50 and p99 indicate a long tail - some projects or runner pools experiencing much worse waits.') {
      gridPos: { x: 11, y: 12, w: 5, h: 5 },
    },
  ]
)
.addPanel(
  row.new(title='Pipeline Creation', collapse=false),
  gridPos={ x: 0, y: 17, w: 24, h: 1 },
)
.addPanels(
  layout.grid([
    panel.basic(
      'Created pipeline count',
      description='Pipeline creation rate over 15-minute windows, compared with the same period one week ago. Use this to spot sudden drops (creation failures, upstream outages) or spikes (retry storms, bulk scheduled pipelines). Upper and lower limits are from last week metrics.',
      linewidth=2,
      unit='short',
      legend_show=false,
    )
    .addTarget(
      target.prometheus(
        'sum(rate(pipelines_created_total{%(sel)s}[$__rate_interval])) * $__interval_ms / 1000' % { sel: selectorWithEnv },
        legendFormat='current',
        interval='15m',
      )
    )
    .addTarget(
      target.prometheus(
        'clamp_min(sum(rate(pipelines_created_total{%(sel)s}[$__rate_interval] offset 1w)) * $__interval_ms / 1000 * 1.1, 0)' % { sel: selectorWithEnv },
        legendFormat='upper limit',
        interval='15m',
      )
    )
    .addTarget(
      target.prometheus(
        'clamp_min(sum(rate(pipelines_created_total{%(sel)s}[$__rate_interval] offset 1w)) * $__interval_ms / 1000 * 0.9, 0)' % { sel: selectorWithEnv },
        legendFormat='lower limit',
        interval='15m',
      )
    )
    .addSeriesOverride({ alias: 'current', color: '#E7D551' })
    .addYaxis(min=0)
    + {
      fieldConfig+: {
        overrides+: [
          {
            matcher: { id: 'byName', options: 'upper limit' },
            properties: [
              { id: 'custom.lineStyle', value: { dash: [8], fill: 'dash' } },
              { id: 'color', value: { fixedColor: '#73BF69', mode: 'fixed' } },
              { id: 'custom.fillBelowTo', value: 'lower limit' },
              { id: 'custom.fillOpacity', value: 10 },
              { id: 'custom.hideFrom', value: { legend: true, tooltip: false, viz: false } },
              { id: 'custom.lineWidth', value: 1 },
              { id: 'custom.spanNulls', value: true },
            ],
          },
          {
            matcher: { id: 'byName', options: 'lower limit' },
            properties: [
              { id: 'custom.lineStyle', value: { dash: [8], fill: 'dash' } },
              { id: 'color', value: { fixedColor: '#73BF69', mode: 'fixed' } },
              { id: 'custom.hideFrom', value: { legend: true, tooltip: false, viz: false } },
              { id: 'custom.lineWidth', value: 1 },
              { id: 'custom.spanNulls', value: true },
              { id: 'custom.fillBelowTo', value: 'upper limit' },
              { id: 'custom.fillOpacity', value: 10 },
            ],
          },
        ],
      },
    },

    panel.basic(
      'Creation rate - per source',
      description='Pipeline creation rate broken down by trigger source (push, merge_request_event, api, trigger, schedule, web, etc.). Use this to identify which source is driving creation volume - useful during incidents to see if a specific source is spiking or dropping.',
      linewidth=1,
      unit='short',
    )
    .addTarget(
      target.prometheus(
        'sum by (source)(sli_aggregations:pipelines_created_total:rate_5m{%(sel)s,source!=""}) > 0' % { sel: selectorWithEnv },
        legendFormat='{{source}} RPS',
      )
    )
    .addYaxis(min=0, label='Requests per Second'),

    panel.basic(
      'Pipeline creation failure ratio',
      description='Pipeline creation failure rate. Failures exclude non-actionable reasons (filtered_by_rules, filtered_by_workflow_rules, filtered_by_no_pipeline, unknown_failure). A growing gap between created and failed lines indicates increasing failure ratio.',
      linewidth=1,
      unit='percentunit',
    )
    .addTarget(
      target.prometheus(
        'sum(rate(gitlab_ci_pipeline_failure_reasons{%(sel)s,reason!~"filtered_by_rules|filtered_by_workflow_rules|filtered_by_no_pipeline|unknown_failure"}[$__rate_interval])) / sum(rate(pipelines_created_total{%(sel)s}[$__rate_interval]))' % { sel: selectorWithEnv },
        legendFormat='pipeline creation failure ratio',
      )
    )
    .addYaxis(label='Failure ratio'),

    text.new(
      title='Pipeline Volume Indicators',
      mode='markdown',
      content=|||
        ## Pipeline Volume Indicators

        **Created pipeline count** shows the rate of pipeline creation compared to the same period one week ago, with a +/-10% envelope. Deviations outside the envelope may indicate changes in user behavior or system issues.

        **Creation rate - per source** breaks down pipeline creation by trigger source (push, web, api, schedule, etc.).

        **Pipeline creation failure ratio** shows the fraction of pipeline creation attempts that result in a failure reason (excluding filtered/workflow rules which are expected).
      |||,
    ),
  ], cols=4, rowHeight=9, startRow=18)
  +
  layout.grid([
    sidekiqQueueApdexPanel(
      'Pipeline creation workers queue Apdex',
      pipelineCreationWorkers,
      description='Ratio of pipeline creation jobs dequeued within their SLO target. Covers CreatePipelineWorker and variants. Compares current vs previous week with 6h/30d error budget burn rate thresholds.',
    ),
    sidekiqExecApdexPanel(
      'Pipeline creation workers execution Apdex',
      pipelineCreationWorkers,
      description='Ratio of pipeline creation jobs completing within their urgency-based duration SLO. A sustained drop indicates the creation chain is taking longer than expected - check DB duration and Gitaly latency.',
    ),
    sidekiqSuccessRatePanel(
      'Pipeline creation workers success rate',
      pipelineCreationWorkers,
      description='Ratio of pipeline creation Sidekiq jobs that completed without error. A drop means CreatePipelineWorker jobs are failing - check logs for error details.',
    ),
    text.new(
      title='Pipeline Creation Sidekiq Workers Overview',
      mode='markdown',
      content=|||
        ## Description

        These workers handle **CI/CD pipeline creation** - the process of turning a `.gitlab-ci.yml` configuration into an executable pipeline with stages and jobs.

        **Key workers**: `CreatePipelineWorker`, `Ci::CreatePipelineWorker`

        **Queue Apdex** measures how quickly jobs are dequeued from Redis. **Execution Apdex** measures how quickly the worker completes once it starts. **Success rate** tracks the fraction of executions that complete without error.
      |||,
    ),
  ], cols=4, rowHeight=9, startRow=27)
  +
  layout.grid([
    sidekiqDbDurationPanel(
      'Pipeline creation avg DB duration',
      pipelineCreationWorkers,
      description='Average database time per job for pipeline creation workers, broken down by queue. Spikes indicate slow queries during pipeline creation.',
    ),
  ], cols=4, rowHeight=9, startRow=36)
)
.addPanel(
  row.new(title='Pipeline Processing', collapse=false),
  gridPos={ x: 0, y: 45, w: 24, h: 1 },
)
.addPanels(
  layout.grid([
    sidekiqQueueApdexPanel(
      'Pipeline processing workers queue Apdex',
      pipelineProcessingWorkers,
      description='Ratio of pipeline processing jobs dequeued within their SLO target. Covers InitialPipelineProcessWorker, PipelineProcessWorker, BuildFinishedWorker, and BuildQueueWorker. A sustained drop means the pipeline state machine loop is stalling - pipelines may get stuck in running status.',
    ),
    sidekiqExecApdexPanel(
      'Pipeline processing workers execution Apdex',
      pipelineProcessingWorkers,
      description='Ratio of pipeline processing jobs completing within their urgency-based duration SLO. Degradation with near-zero queue depth indicates a processing-level bug rather than capacity issues.',
    ),
    sidekiqSuccessRatePanel(
      'Pipeline processing workers success rate',
      pipelineProcessingWorkers,
      description='Ratio of pipeline processing Sidekiq jobs that completed without error. Covers InitialPipelineProcessWorker, PipelineProcessWorker, BuildFinishedWorker, and BuildQueueWorker. A drop here with near-zero queue depth is a strong signal of an application-layer bug.',
    ),
    text.new(
      title='Pipeline Processing Sidekiq Workers Overview',
      mode='markdown',
      content=|||
        ## Description

        These workers form the **pipeline state machine loop** - they advance pipelines through their lifecycle by processing stage transitions, handling build completions, and managing the build queue.

        **Key workers**: `Ci::InitialPipelineProcessWorker`, `PipelineProcessWorker`, `Ci::BuildFinishedWorker`, `BuildQueueWorker`
      |||,
    ),
  ], cols=4, rowHeight=9, startRow=46)
  +
  layout.grid([
    panel.basic(
      'Pipeline processing workers concurrency',
      description='Current concurrent job count for pipeline processing workers under the Sidekiq concurrency limiter. If a worker flatlines at its limit while queue depth grows, jobs are being deferred and may get stuck.',
      linewidth=1,
      unit='short',
    )
    .addTarget(
      target.prometheus(
        'max by (worker)(max_over_time(sidekiq_concurrency_limit_current_concurrent_jobs{%(sel)s,worker=~"%(w)s"}[$__interval]))' % { sel: selectorWithEnv, w: pipelineProcessingWorkers },
        legendFormat='{{worker}}',
      )
    )
    .addYaxis(min=0),

    panel.basic(
      'Pipeline processing failures',
      description='unknown_failure and null values are the only relevant processing failures',
      linewidth=1,
      unit='short',
      stack=true,
      legend_alignAsTable=false,
    )
    .addTarget(
      target.prometheus(
        'sum(increase(gitlab_ci_pipeline_failure_reasons{%(sel)s,reason=~"unknown_failure|^$"}[30m]))' % { sel: selectorWithEnv },
        legendFormat='failed count',
      )
    ),

    sidekiqDbDurationPanel(
      'Pipeline processing avg DB duration',
      pipelineProcessingWorkers,
      description='Average database time per job for pipeline processing workers. PipelineProcessWorker and BuildFinishedWorker are the most DB-intensive. Spikes correlate with pipeline state transition overhead.',
    ),
  ], cols=4, rowHeight=9, startRow=55)
)
.addPanel(
  row.new(title='Job Queueing', collapse=false),
  gridPos={ x: 0, y: 64, w: 24, h: 1 },
)
.addPanels(
  layout.grid([
    basic.heatmap(
      title=runnerIcon + 'Pending job queue durations',
      description='Distribution of time jobs spend in the queue before a runner accepts them. A widening or rising distribution indicates runners cannot keep up with the incoming job rate.',
      query='sum by (le)(increase(gitlab_runner_job_queue_duration_seconds_bucket{%(sel)s}[$__rate_interval]))' % { sel: selectorRunnerRegex },
      yAxis_format='s',
      color_colorScheme='interpolateSpectral',
      color_mode='scheme',
    ) + {
      links: [{ title: 'ci-runners: Jobs queuing overview', url: 'https://dashboards.gitlab.net/d/ci-runners-queuing-overview/ci-runners3a-jobs-queuing-overview' }],
      options: {
        calculate: false,
        cellGap: 1,
        cellValues: { unit: 's' },
        color: { exponent: 0.5, fill: 'dark-orange', mode: 'scheme', reverse: false, scale: 'exponential', scheme: 'Spectral', steps: 64 },
        exemplars: { color: 'rgba(255,0,255,0.7)' },
        filterValues: { le: 1e-9 },
        legend: { show: true },
        rowsFrame: { layout: 'auto' },
        tooltip: { mode: 'single', showColorScale: false, yHistogram: false },
        yAxis: { axisPlacement: 'left', reverse: false, unit: 's' },
      },
    },

    panel.basic(
      runnerIcon + 'Job queue duration SLO violation rate',
      description='Ratio of jobs that exceeded acceptable queuing duration vs total jobs queued. This normalizes the raw exceeded count against volume.',
      linewidth=2,
      unit='percentunit',
      thresholdSteps=[
        { value: null, color: 'green' },
        { value: 0.1, color: '#EAB839' },
        { value: 0.2, color: 'red' },
      ],
    )
    .addTarget(
      target.prometheus(
        'sum(rate(gitlab_runner_acceptable_job_queuing_duration_exceeded_total{%(sel)s}[$__rate_interval])) / sum(rate(gitlab_runner_jobs_total{%(sel)s}[$__rate_interval]))' % { sel: selectorRunnerRegex },
        legendFormat='exceeded rate',
      )
    )
    .addYaxis(min=0)
    + {
      links: [{ title: 'ci-runners: Jobs queuing overview', url: 'https://dashboards.gitlab.net/d/ci-runners-queuing-overview/ci-runners3a-jobs-queuing-overview' }],
      fieldConfig+: {
        defaults+: {
          custom+: {
            thresholdsStyle: { mode: 'dashed+area' },
          },
        },
      },
    },

  ], cols=3, rowHeight=8, startRow=65)
  +
  [
    text.new(
      title='Job Queue Duration',
      mode='markdown',
      content=|||
        # Description

        Time a job spends waiting in `pending` status before a runner picks it up, measured by Rails in `RegisterJobService` via `job_queue_duration_seconds`. Split by runner type: GitLab-managed (shared) vs self-managed (project/group).

        - **p50 / p99 panels** - Median and 99th percentile queue wait over the last 24h UTC.
        - **Today vs yesterday** - Percentage change in p50 and p99 vs the prior day.
        - **7-day trend** - Percentage change in p50 and p99 vs the prior 7 days.

        ### Healthy baselines

        | Runner type | p50 | p99 |
        |-------------|-----|-----|
        | GitLab-managed (shared) | < 1s | 20-80s |
        | Self-managed | < 1s | Varies by fleet size |

        Queue duration is a direct customer experience metric - it is the wait time users see between triggering a pipeline and their job starting to run.
      |||,
    ) { gridPos: { x: 16, y: 65, w: 8, h: 16 } },
  ]
  +
  layout.grid([
    panel.basic(
      'Job queue duration - observation rate by bucket',
      description='Per-second rate of job pickups falling into each queue duration bucket. Each line represents a cumulative histogram bucket boundary (e.g., le="10" counts jobs that waited ≤ 10s). Higher lines mean more jobs. If higher-bucket lines grow while lower-bucket lines stay flat, jobs are waiting longer for runners.',
      unit='ops',
      legend_show=false,
      legend_alignAsTable=false,
    )
    .addTarget(
      target.prometheus(
        'sum by (le)(sli_aggregations:job_queue_duration_seconds_bucket:rate_5m{%(sel)s})' % { sel: selector },
        legendFormat='{{le}}',
        interval='5m',
      )
    )
    + {
      options+: {
        legend+: {
          calcs: ['p50', 'p95', 'p99'],
        },
      },
    },

    panel.basic(
      'Job queue wait time',
      description='Job queue duration, split by shared vs non-shared runners. The p99 shows worst-case wait times, while the average shows typical experience. Large divergence between p99 and average indicates a long tail - some projects experiencing much worse queue times than the median.',
      linewidth=1,
      unit='s',
      legend_alignAsTable=false,
      legend_min=false,
      legend_max=false,
      legend_avg=false,
      legend_current=false,
    )
    .addTarget(
      target.prometheus(
        'histogram_quantile(0.99, sum by (le, shared_runner)(rate(job_queue_duration_seconds_bucket{%(sel)s}[$__rate_interval])))' % { sel: selector },
        legendFormat='p99 (shared runner={{shared_runner}})',
      )
    )
    .addTarget(
      target.prometheus(
        'sum by (shared_runner)(rate(job_queue_duration_seconds_sum{%(sel)s}[$__rate_interval])) / sum by (shared_runner)(rate(job_queue_duration_seconds_count{%(sel)s}[$__rate_interval]))' % { sel: selector },
        legendFormat='avg (shared runner={{shared_runner}})',
      )
    )
    .addSeriesOverride({ alias: 'avg (shared runner=false)', color: 'green' })
    .addSeriesOverride({ alias: 'p99 (shared runner=false)', color: 'dark-green' })
    + {
      links: [{ title: 'ci-runners: Jobs queuing overview', url: 'https://dashboards.gitlab.net/d/ci-runners-queuing-overview/ci-runners3a-jobs-queuing-overview' }],
    },
  ], cols=3, rowHeight=8, startRow=73)
  +
  layout.grid([
    basic.heatmap(
      title='Active runners per project histogram',
      description='Heatmap of the number of active runners that can process jobs in a project queue. Low values indicate limited runner availability for specific projects, which can cause extended queue times even when overall fleet capacity looks healthy.',
      query='sum by (le)(increase(gitlab_ci_queue_active_runners_total_bucket{%(sel)s}[$__rate_interval]))' % { sel: selectorRunnerRegex },
      yAxis_format='short',
      color_colorScheme='interpolateOranges',
      color_mode='scheme',
    ) + {
      options: {
        calculate: false,
        calculation: {},
        cellGap: 1,
        cellRadius: 2,
        cellValues: { decimals: 3 },
        color: { exponent: 0.5, fill: '#FA6400', mode: 'scheme', reverse: false, scale: 'exponential', scheme: 'Oranges', steps: 128 },
        exemplars: { color: 'rgba(255,0,255,0.7)' },
        filterValues: { le: 1e-9 },
        legend: { show: true },
        rowsFrame: { layout: 'auto' },
        showValue: 'never',
        tooltip: { mode: 'single', showColorScale: false, yHistogram: true },
        yAxis: { axisPlacement: 'left', reverse: false, unit: 'short' },
      },
    },

    panel.basic(
      runnerIcon + 'Pending jobs queue size',
      description='Current size of the pending job queue. This is a point-in-time gauge - a rising trend means jobs are accumulating faster than runners can pick them up. Compare with runner capacity and job rate to determine if the bottleneck is supply (runners) or demand (job volume).',
      linewidth=2,
      unit='short',
    )
    .addTarget(
      target.prometheus(
        'max(gitlab_runner_job_queue_size{%(sel)s})' % { sel: selectorRunnerRegex },
        legendFormat='queue size',
      )
    )
    .addYaxis(min=0)
    + {
      links: [{ title: 'ci-runners: Jobs queuing overview', url: 'https://dashboards.gitlab.net/d/ci-runners-queuing-overview/ci-runners3a-jobs-queuing-overview' }],
    },

    panel.basic(
      'Job pickup miss rate',
      description='Ratio of missed job registration attempts vs total attempts. A job register miss means a runner tried to pick up a job but could not (conflict, job already taken, pre-assignment mismatch). Compares current week vs previous week. Sustained increases may indicate runner contention or stale job assignments.',
      linewidth=2,
      unit='percentunit',
    )
    .addTarget(
      target.prometheus(
        'sum(rate(job_register_attempts_failed_total{%(sel)s}[$__rate_interval])) / sum(rate(job_register_attempts_total{%(sel)s}[$__rate_interval]))' % { sel: selectorRunnerRegex },
        legendFormat='failure rate',
      )
    )
    .addTarget(
      target.prometheus(
        'sum(rate(job_register_attempts_failed_total{%(sel)s}[$__rate_interval] offset 1w)) / sum(rate(job_register_attempts_total{%(sel)s}[$__rate_interval] offset 1w))' % { sel: selectorRunnerRegex },
        legendFormat='last week',
      )
    )
    .addYaxis(min=0)
    + {
      fieldConfig+: {
        defaults+: {
          color: { fixedColor: 'red', mode: 'fixed' },
        },
        overrides+: [
          {
            matcher: { id: 'byName', options: 'last week' },
            properties: [
              { id: 'custom.lineStyle', value: { dash: [4], fill: 'dot' } },
              { id: 'color', value: { mode: 'fixed' } },
              { id: 'custom.lineWidth', value: 1 },
            ],
          },
        ],
      },
    },
  ], cols=3, rowHeight=8, startRow=81)
  +
  layout.grid([
    panel.basic(
      'Job pickup rate',
      description='Total rate of jobs being picked up by runners (job_queue_duration_seconds_count). Compares current week vs previous week. A significant drop without a corresponding drop in creation rate suggests runners are not picking up jobs - check runner health, autoscaling, and queue sizes.',
      linewidth=1,
      unit='cps',
    )
    .addTarget(
      target.prometheus(
        'sum(rate(job_queue_duration_seconds_count{%(sel)s}[$__rate_interval]))' % { sel: selector },
        legendFormat='job queue rate',
      )
    )
    .addTarget(
      target.prometheus(
        'sum(rate(job_queue_duration_seconds_count{%(sel)s}[$__rate_interval] offset 1w))' % { sel: selector },
        legendFormat='last week',
      )
    )
    .addSeriesOverride({ alias: 'last week', dashes: true, dashLength: 4, color: '#dddddd80', linewidth: 1 }),

    panel.basic(
      'Job processing throughput — pickup rate',
      description='Rate of internal queue operations by type: build_queue_push (job enqueued), build_queue_pop (runner picked up), build_not_pick (skipped), build_conflict_exception (race condition). Also shows the pop/push ratio - values below 100% mean the queue is accumulating.',
      linewidth=1,
      unit='reqps',
      legend_rightSide=true,
      legend_min=false,
      legend_max=false,
      legend_avg=false,
    )
    .addTarget(
      target.prometheus(
        'sum by (operation)(rate(gitlab_ci_queue_operations_total{operation=~"build_queue_push|build_queue_pop|build_not_pick|build_conflict_exception|runner_pre_assign_checks_failed|queue_depth_limit|queue_replication_lag",%(sel)s}[$__rate_interval]))' % { sel: selector },
        legendFormat='{{operation}}',
        interval='10m',
      )
    )
    .addTarget(
      target.prometheus(
        'sum(rate(gitlab_ci_queue_operations_total{operation="build_queue_pop",%(sel)s}[$__rate_interval])) / sum(rate(gitlab_ci_queue_operations_total{operation="build_queue_push",%(sel)s}[$__rate_interval]))' % { sel: selector },
        legendFormat='Pickup rate %',
        interval='10m',
      )
    )
    + {
      links: [{ title: 'Pipeline Execution group dashboard', url: 'https://dashboards.gitlab.net/d/stage-groups-pipeline_execution/c791104' }],
      fieldConfig+: {
        defaults+: {
          custom+: {
            thresholdsStyle: { mode: 'off' },
          },
        },
        overrides+: [
          {
            matcher: { id: 'byName', options: 'Pickup rate %' },
            properties: [
              { id: 'unit', value: 'percentunit' },
              { id: 'custom.thresholdsStyle', value: { mode: 'off' } },
              { id: 'custom.lineStyle', value: { dash: [10, 10], fill: 'dash' } },
              {
                id: 'thresholds',
                value: {
                  mode: 'absolute',
                  steps: [{ color: 'red', value: 0 }, { color: 'green', value: 0.95 }],
                },
              },
            ],
          },
        ],
      },
    },

    panel.basic(
      runnerIcon + 'Jobs failure rate',
      description='Ratio of failed jobs vs total jobs completed. Compares current week vs previous week. This measures runner-side execution failures (infrastructure failures, timeout, etc.) - distinct from pipeline failure reasons which are application-level. A rising trend indicates degraded runner reliability.',
      linewidth=2,
      unit='percentunit',
    )
    .addTarget(
      target.prometheus(
        'sum(rate(gitlab_runner_failed_jobs_total{%(sel)s}[$__rate_interval])) / sum(rate(gitlab_runner_jobs_total{%(sel)s}[$__rate_interval]))' % { sel: selectorRunnerRegex },
        legendFormat='failure rate',
      )
    )
    .addTarget(
      target.prometheus(
        'sum(rate(gitlab_runner_failed_jobs_total{%(sel)s}[$__rate_interval] offset 1w)) / sum(rate(gitlab_runner_jobs_total{%(sel)s}[$__rate_interval] offset 1w))' % { sel: selectorRunnerRegex },
        legendFormat='last week',
      )
    )
    .addYaxis(min=0)
    + {
      fieldConfig+: {
        overrides+: [
          {
            matcher: { id: 'byName', options: 'last week' },
            properties: [
              { id: 'custom.lineStyle', value: { dash: [4], fill: 'dot' } },
              { id: 'color', value: { mode: 'fixed' } },
              { id: 'custom.lineWidth', value: 1 },
            ],
          },
        ],
      },
    },
  ], cols=3, rowHeight=8, startRow=89)
  +
  layout.grid([
    panel.basic(
      'Pipeline queue growth rate',
      description='Rate of change (derivative) of the CI job queue size. Positive values mean the queue is growing (jobs arriving faster than runners pick them up); negative means it is draining. Sustained positive values indicate a capacity shortfall.',
      linewidth=1,
      unit='ops',
      legend_alignAsTable=false,
      thresholdSteps=[
        { value: null, color: 'green' },
        { value: 2, color: '#EAB839' },
        { value: 5, color: 'red' },
      ],
    )
    .addTarget(
      target.prometheus(
        'sum(deriv(gitlab_ci_current_queue_size{%(sel)s}[$__rate_interval]))' % { sel: selector },
        legendFormat='Queue growth',
        interval='10m',
      )
    )
    + {
      fieldConfig+: {
        defaults+: {
          custom+: {
            thresholdsStyle: { mode: 'line' },
          },
        },
      },
    },
  ], cols=3, rowHeight=8, startRow=97)
)
.addPanel(
  row.new(title='Job Execution', collapse=false),
  gridPos={ x: 0, y: 105, w: 24, h: 1 },
)
.addPanels(
  layout.grid([
    panel.basic(
      runnerIcon + 'ci-runners Service Apdex',
      description='Overall ci-runners service Apdex ratio showing min and avg over each interval. Includes 6h and 30d error budget burn rate thresholds and previous week comparison. This is the top-level service health indicator - if this degrades, drill into the per-worker Apdex panels to isolate which component is responsible.',
      linewidth=2,
      unit='percentunit',
    )
    .addTarget(
      target.prometheus(
        'min_over_time(gitlab_service_apdex:ratio_5m{%(sel)s,type="ci-runners"}[$__interval])' % { sel: selectorWithMonitor },
        legendFormat='ci-runners apdex',
      )
    )
    .addTarget(
      target.prometheus(
        '(1 - 6 * (1 - avg(slo:min:events:gitlab_service_apdex:ratio{component="",monitor="global",type="ci-runners"})))',
        legendFormat='6h Degradation SLO (5% of monthly error budget)',
        interval='5m',
      )
    )
    .addTarget(
      target.prometheus(
        '(1 - 14.4 * (1 - avg(slo:min:events:gitlab_service_apdex:ratio{component="",monitor="global",type="ci-runners"})))',
        legendFormat='1h Outage SLO (2% of monthly error budget)',
        interval='5m',
      )
    )
    .addTarget(
      target.prometheus(
        'avg_over_time(gitlab_service_apdex:ratio_5m{%(sel)s,type="ci-runners"}[$__interval])' % { sel: selectorWithMonitor },
        legendFormat='ci-runners apdex avg',
      )
    )
    .addTarget(
      target.prometheus(
        'gitlab_service_apdex:ratio_5m{%(sel)s,type="ci-runners"} offset 1w' % { sel: selectorWithMonitor },
        legendFormat='last week',
      )
    )
    .addYaxis(max=1)
    .addSeriesOverride({ alias: '/6h Degradation SLO.*/', dashes: true, dashLength: 4, color: '#FF4500', linewidth: 2 })
    .addSeriesOverride({ alias: '/1h Outage SLO.*/', dashes: true, dashLength: 4, color: '#F2495C', linewidth: 4 })
    .addSeriesOverride({ alias: 'ci-runners apdex avg', color: '#5794F280', linewidth: 1, fillBelowTo: 'ci-runners apdex' })
    .addSeriesOverride({ alias: 'last week', dashes: true, dashLength: 4, color: '#dddddd80', linewidth: 1 })
    .addSeriesOverride({ alias: 'ci-runners apdex', color: '#E7D551' })
    + {
      links: [{ title: 'ci-runners: Overview', url: 'https://dashboards.gitlab.net/d/ci-runners-main/ci-runners3a-overview' }],
    },

    panel.basic(
      runnerIcon + 'Runner to GitLab API error rate',
      description='Rate of 4xx/5xx errors from runner API requests (excluding 409 Conflict, which is expected during job contention). Compares current week vs previous week. Spikes in 5xx errors indicate backend issues serving the runner fleet; 4xx spikes may indicate authentication or authorization problems.',
      linewidth=2,
      unit='reqps',
    )
    .addTarget(
      target.prometheus(
        'sum by ()(sli_aggregations:gitlab_runner_api_request_statuses_total:rate_5m{%(sel)s,status!="409",status=~"4..|5.."}) > 0' % { sel: selectorWithEnv },
        legendFormat='overall',
      )
    )
    .addTarget(
      target.prometheus(
        'sum by ()(sli_aggregations:gitlab_runner_api_request_statuses_total:rate_5m{%(sel)s,status!="409",status=~"4..|5.."} offset 1w) > 0' % { sel: selectorWithEnv },
        legendFormat='last week',
      )
    )
    .addYaxis(min=0, label='Errors')
    + {
      fieldConfig+: {
        overrides+: [
          {
            matcher: { id: 'byName', options: 'last week' },
            properties: [
              { id: 'custom.lineWidth', value: 1 },
              { id: 'custom.lineStyle', value: { dash: [4], fill: 'dot' } },
              { id: 'color', value: { mode: 'fixed' } },
            ],
          },
        ],
      },
    },
  ], cols=2, rowHeight=8, startRow=106)
  +
  layout.grid([
    panel.basic(
      'Job failures - system-caused',
      description='Hourly increase of job failure reasons attributable to platform infrastructure: stuck_or_timeout_failure, runner_system_failure, scheduler_failure, data_integrity_failure, environment_creation_failure, job_router_failure, stale_schedule. These are failures the platform owns, not user script errors.',
      linewidth=2,
      unit='ops',
      stack=true,
      legend_alignAsTable=false,
      legend_current=false,
      legend_min=false,
      legend_max=false,
      legend_avg=false,
    )
    .addTarget(
      target.prometheus(
        'sum by (reason)(sli_aggregations:gitlab_ci_job_failure_reasons:rate_5m{%(sel)s,reason=~"%(reasons)s"})' % { sel: selectorWithEnv, reasons: jobSystemFailureReasons },
        legendFormat='{{reason}}',
        interval='5m',
      )
    )
    + {
      options+: {
        legend+: {
          calcs: ['lastNotNull'],
        },
      },
    },

    panel.basic(
      'Job failures - others',
      description='Hourly increase of job failure reasons excluding system-caused reasons. Includes script_failure (user code), ci_quota_exceeded, user_blocked, and other non-infrastructure causes. Useful as a baseline for normal user-caused failure volume.',
      linewidth=2,
      unit='ops',
      stack=true,
      legend_alignAsTable=false,
      legend_current=false,
      legend_min=false,
      legend_max=false,
      legend_avg=false,
    )
    .addTarget(
      target.prometheus(
        'sum by (reason)(sli_aggregations:gitlab_ci_job_failure_reasons:rate_5m{%(sel)s,reason!~"%(reasons)s"})' % { sel: selectorWithEnv, reasons: jobSystemFailureReasons },
        legendFormat='{{reason}}',
        interval='5m',
      )
    ),
  ], cols=2, rowHeight=8, startRow=114)
  +
  layout.grid([
    panel.basic(
      'Infra-attributable error rate %',
      description='% of job failures caused by platform infrastructure, excluding user script failures',
      linewidth=2,
      unit='percentunit',
      legend_rightSide=true,
      legend_min=false,
      legend_max=false,
      thresholdSteps=[
        { value: null, color: 'green' },
        { value: 0.2, color: '#EAB839' },
        { value: 0.5, color: 'red' },
      ],
    )
    .addTarget(
      target.prometheus(
        'gitlab_component_errors:ratio_5m{type="ci-orchestration",component="job_infra_failure_ratio",%(sel)s}' % { sel: selectorWithMonitor },
        legendFormat='Total Infra error rate %',
        interval='5m',
      )
    )
    .addTarget(
      target.prometheus(
        'sum by (reason)(sli_aggregations:gitlab_ci_job_failure_reasons:rate_5m{%(sel)s,reason!~"%(reasons)s"}) / on() group_left() sum(sli_aggregations:gitlab_ci_job_failure_reasons:rate_5m{%(sel)s})' % { sel: selectorWithEnv, reasons: jobNonInfraFailureReasons },
        legendFormat='{{reason}}',
        interval='5m',
      )
    )
    .addSeriesOverride({ alias: 'Total Infra error rate %', dashes: true, dashLength: 10 })
    .addYaxis(min=0)
    + {
      fieldConfig+: {
        defaults+: {
          custom+: {
            thresholdsStyle: { mode: 'dashed+area' },
          },
        },
      },
    },
  ], cols=2, rowHeight=10, startRow=122)
)
.trailer()
