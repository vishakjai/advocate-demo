local sidekiqHelpers = import '../../../metrics-catalog/services/lib/sidekiq-helpers.libsonnet';
local utils = import './utils.libsonnet';
local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics-catalog.libsonnet';
local durationParser = import 'utils/duration-parser.libsonnet';
local strings = import 'utils/strings.libsonnet';

local baseSelector = {
  stage: '$stage',
  environment: '$environment',
  monitor: 'global',
};

// In prior versions of Grafana, threshold configuration is static only. It does
// not support variables, nor dynamic value from any source. After Grafana v8.1,
// the team introduces a new "Config From Query" transformation that allows us
// to convert a result from a target to become panel configuration.
//
// dynamicThresholds sets a single threshold value based on the returned value
// of the input query.
local dynamicThresholds(panel, query) =
  panel
  .addTarget(
    promQuery.target(
      query,
      legendFormat='budget',
    )
  ) + {
    // TODO: this approach is not sustainable. Unfortunately, transformation
    // support in grafonnet-lib is limited, only table panel is targeted:
    // https://github.com/grafana/grafonnet-lib/pull/265
    transformations+: [
      {
        id: 'configFromData',
        options: {
          configRefId: 'B',
          mappings: [
            {
              fieldName: 'budget',
              handlerKey: 'threshold1',
            },
          ],
        },
      },
    ],
  };

// 10 years in seconds
local staticThresholdDefinitions(slaTarget) =
  local infinity = 315360000;
  // Align thresholds with error budget report rounding logic.
  // See: https://gitlab.com/gitlab-org/error-budget-reports/-/blob/main/lib/report.rb
  local decimals = 4;
  local roundingBoundary = slaTarget - (0.5 / std.pow(10, decimals));
  [
    {
      availability: {
        from: 0,
        to: roundingBoundary,
      },
      // secondsRemaining heuristic is simple. It changes the appearance of the
      // panel if the remaining seconds are below zero. Unfortunately, AFAIK,
      // grafonnet-lib does not support one-ended range. Grafana doesn't support
      // Infinity value either. Setting a too big value will make Grafana
      // overflowed. So, I picked 10 years as Infinity. Who queries 10 years of
      // data anyway.
      secondsRemaining: {
        from: 0 - infinity,
        to: 0,
      },
      color: 'red',
      text: '🥵 Unhealthy',
    },
    {
      availability: {
        from: roundingBoundary,
        to: 1.0,
      },
      secondsRemaining: {
        from: 0,
        to: infinity,
      },
      color: 'green',
      text: '🥳 Healthy',
    },
  ];

// staticThresholds setups the thresholds of panels based on a set of static
// (server-generated) settings.
local staticThresholds(slaTarget, range, type) =
  local definitions = staticThresholdDefinitions(slaTarget);
  local thresholdStep(color, value) = { color: color, value: value };
  std.map(
    function(definition) thresholdStep(definition.color, definition[type].from),
    std.sort(definitions, function(definition) definition[type].from)
  );

local errorBudgetStatusPanel(queries, slaTarget, range, groupSelectors) =
  local definitions = staticThresholdDefinitions(slaTarget);
  local mappings = std.mapWithIndex(
    function(index, definition) {
      type: 'range',
      options: {
        from: definition.availability.from,
        to: definition.availability.to,
        result: {
          color: definition.color,
          index: index,
          text: definition.text,
        },
      },
    },
    definitions
  );
  basic.statPanel(
    '',
    '',
    staticThresholds(slaTarget, range, 'availability'),
    mappings=mappings,
    query=queries.errorBudgetRatio(
      baseSelector {
        stage_group: groupSelectors,
      },
    ),
    legendFormat='',
    unit='none',
    decimals='2',
    textMode='value',
  );

local availabilityStatPanel(queries, slaTarget, range, groupSelectors) =
  basic.statPanel(
    '',
    'Availability',
    staticThresholds(slaTarget, range, 'availability'),
    query=queries.errorBudgetRatio(
      baseSelector {
        stage_group: groupSelectors,
      },
    ),
    legendFormat='%',
    decimals=2,
    unit='percentunit',
  );

local availabilityTargetStatPanel(queries, slaTarget, range, groupSelectors) =
  basic.statPanel(
    'Target:',
    '',
    color='gray',
    query='%(slaTarget).4f * 100.0' % slaTarget,
    legendFormat='',
    unit='percent',
    decimals='2'
  );

local timeRemainingTargetStatPanel(queries, slaTarget, range, groupSelectors) =
  local title =
    if utils.isDynamicRange(range) then
      'Budget:'
    else
      '%(range)s budget:' % { range: range };
  basic.statPanel(
    title,
    '',
    color='gray',
    query=queries.budgetSecondsForRange(),
    legendFormat='',
    unit='s',
  );

local timeRemainingStatPanel(queries, slaTarget, range, groupSelectors) =
  basic.statPanel(
    '',
    'Budget remaining',
    staticThresholds(slaTarget, range, 'secondsRemaining'),
    query=queries.errorBudgetTimeRemaining(
      baseSelector {
        stage_group: groupSelectors,
      },
    ),
    legendFormat='',
    unit='s',
  );

local timeSpentStatPanel(queries, slaTarget, range, groupSelectors) =
  local panel = basic.statPanel(
    '',
    'Budget spent',
    [],
    query=queries.errorBudgetTimeSpent(
      baseSelector {
        stage_group: groupSelectors,
      },
    ),
    legendFormat='',
    unit='s',
  );
  // The threshold is the budget of the range.
  dynamicThresholds(panel, queries.budgetSecondsForRange());

local timeSpentTargetStatPanel(queries, slaTarget, range, groupSelectors) =
  local title =
    if utils.isDynamicRange(range) then
      'Budget:'
    else
      '%(range)s budget:' % { range: range };
  basic.statPanel(
    title,
    '',
    color='gray',
    query=queries.budgetSecondsForRange(),
    legendFormat='',
    unit='s',
  );

local explanationPanel(slaTarget, range, group) =
  basic.text(
    title='Info',
    mode='markdown',
    content=|||
      ### [Error budget](https://about.gitlab.com/handbook/engineering/error-budgets/)

      These error budget panels show an aggregate of SLIs across all components.
      However, not all components have been implemented yet.

      The [handbook](https://about.gitlab.com/handbook/engineering/error-budgets/)
      explains how these budgets are used.

      Read more about how the error budgets are calculated in the
      [stage group dashboard documentation](https://docs.gitlab.com/ee/development/stage_group_observability/dashboards/stage_group_dashboard.html#error-budget-panels).

      The error budget is compared to our SLO of %(slaTarget)s and is always in
      a range of 28 days from the selected end date in Grafana.

      ### Availability

      The availability shows the percentage of operations labeled with one of the
      categories owned by %(group)s with satisfactory completion.

      ### Budget remaining

      The error budget in minutes is calculated based on the %(slaTarget)s.
      There are 40320 minutes in 28 days, we allow %(budgetRatio)s of failures, which
      means the budget in minutes is %(budgetMinutes)s minutes.

      The budget remaining shows how many minutes have not been spent in the
      past 28 days.

      ### Minutes spent

      This shows the total minutes spent over the past 28 days.

      For example, if there were 403200 (28 * 24 * 60) operations in 28 days.
      This would be 1 every minute. If 10 of those were unsatisfactory, that
      would mean 10 minutes of the budget were spent.
    ||| % {
      slaTarget: '%.2f%%' % (slaTarget * 100.0),
      budgetRatio: '%.2f%%' % ((1 - slaTarget) * 100.0),
      budgetMinutes: '%s' % utils.budgetMinutes(slaTarget, range),
      group: group,
    },
  );

local localUnitOverride(fieldName) = {
  matcher: { id: 'byName', options: fieldName },
  properties: [{
    id: 'unit',
    value: 'locale',
  }],
};

local violationRatePanel(queries, group) =
  local selector = baseSelector {
    stage_group: group,
  };
  local aggregationLabels = ['component', 'violation_type', 'type'];
  panel.table(
    title='Budget failures',
    description='Number of failures contributing to the budget send per component and type ',
    styles=null,  // https://github.com/grafana/grafonnet-lib/issues/240
    queries=[
      utils.rateToOperationCount(queries.errorBudgetViolationRate(selector, aggregationLabels)),
      utils.rateToOperationCount(queries.errorBudgetOperationRate(selector, aggregationLabels)),
    ],
    transformations=[
      {
        id: 'merge',
      },
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
          },
          indexByName: {
            violation_type: 0,
            type: 1,
            component: 2,
            'Value #A': 3,
            'Value #B': 4,
          },
          renameByName: {
            'Value #A': 'failures past 28 days',
            'Value #B': 'measurements past 28 days',
          },
        },
      },
    ],
  ) + {
    options: {
      sortBy: [{
        displayName: 'failures past 28 days',
        desc: true,
      }],
      footer: {
        show: true,
        reducer: ['sum'],
        countRows: false,
        fields: [
          'Value #A',
          'Value #B',
        ],
      },
    },
    fieldConfig+: {
      overrides+: [
        {
          matcher: { id: 'byName', options: 'type' },
          properties: [{
            id: 'links',
            value: [{
              targetBlank: true,
              title: '${__value.text} overview: See ${__data.fields.component} SLI for details',
              url: 'https://dashboards.gitlab.net/d/${__value.text}-main',
            }],
          }],
        },
      ] + [
        localUnitOverride(fieldName)
        for fieldName in ['failures past 28 days', 'measurements past 28 days']
      ],
    },
  };

local violationRateExplanation =
  basic.text(
    title='Info',
    mode='markdown',
    content=|||
      This table shows the failures that contribute to the spend of the error budget.
      Fixing the top item in this table will have the biggest impact on the
      budget spend.

      A failure is one of 2 types:

      - **error**: An operation that failed: 500 response, failed background job.
      - **apdex**: This means an operation that succeeded, but did not perform within the set threshold.

      See the [developer documentation](https://gitlab.com/gitlab-org/gitlab/-/blob/master/doc/development/stage_group_dashboards.md#error-budget)
      to learn more about this.

      The component refers to the component in our stack where the violation occurred.
      The most common ones are:

      - **puma**: This component signifies requests handled by rails
      - **sidekiq_execution**: This component signifies background jobs executed by Sidekiq

      To find the endpoint that is attributing to the budget spend and a violation type
      we can use the logs over a 7 day range. Links for puma and sidekiq are available on the right.
      These logs list the endpoints that had the most violations over the past 7 days.

      The "Other" row is the sum of all the other violations excluding the top ones
      that are listed.
    |||,
  );

local sidekiqDurationThresholdByFilter =
  local knownDurationThresholds = std.map(
    function(sloName)
      sidekiqHelpers.slos[sloName].executionDurationSeconds,
    std.objectFields(sidekiqHelpers.slos)
  );
  local thresholds = {
    'json.shard: "urgent"': sidekiqHelpers.slos.urgent.executionDurationSeconds,
    'not json.shard: "urgent"': sidekiqHelpers.slos.lowUrgency.executionDurationSeconds,
  };
  local definedThresholds = std.set(std.sort(std.objectValues(thresholds)));
  local knownThresholds = std.set(std.sort(knownDurationThresholds));
  if std.assertEqual(definedThresholds, knownThresholds) then
    thresholds;

local sidekiqDurationTableFilters = std.map(
  function(filter)
    local duration = sidekiqDurationThresholdByFilter[filter];
    {
      label: 'Jobs exceeding %is' % duration,
      input: {
        language: 'kuery',
        query: '%(filter)s AND json.duration_s > %(duration)i' % {
          filter: filter,
          duration: duration,
        },
      },
    },
  std.objectFields(sidekiqDurationThresholdByFilter),
);
local logLinks(featureCategories, stageGroup) =
  local featureCategoryFilters = matching.matchers({
    'json.meta.feature_category': featureCategories,
  });
  local withDurationFilters = [matching.existsFilter('json.duration_s'), matching.existsFilter('json.target_duration_s')];
  local timeFrame = elasticsearchLinks.timeRange('now-7d', 'now');

  local railsSplitColumns = [
    'json.meta.caller_id.keyword',
    'json.request_urgency.keyword',
    'json.target_duration_s',
  ];
  local apdexAgg = {
    enabled: true,
    id: '3',
    params: {
      customLabel: 'Operations over specified threshold (apdex)',
      field: 'json.duration_s',
      json: '{"script": "doc[\'json.duration_s\'].value > doc[\'json.target_duration_s\'].value ? 1 : 0"}',
    },
    schema: 'metric',
    type: 'sum',
  };

  local railsRequestsApdexTable = elasticsearchLinks.buildElasticTableCountVizURL(
    'rails',
    featureCategoryFilters + withDurationFilters,
    splitSeries=railsSplitColumns,
    timeRange=timeFrame,
    extraAggs=[
      apdexAgg,
    ],
    orderById='3',
  );

  local pumaErrorsTable = elasticsearchLinks.buildElasticTableFailureCountVizURL(
    'rails', featureCategoryFilters, splitSeries=railsSplitColumns, timeRange=timeFrame
  );

  local railsAllRequestsTable = elasticsearchLinks.buildElasticTableCountVizURL(
    'rails',
    featureCategoryFilters + withDurationFilters,
    splitSeries=railsSplitColumns,
    timeRange=timeFrame,
    extraAggs=[
      apdexAgg,
      {
        enabled: true,
        id: '4',
        params: {
          customLabel: 'Failing requests (error)',
          field: 'json.status',
          json: '{"script": "doc[\'json.status\'].value >= 500 ? 1 : 0"}',
        },
        schema: 'metric',
        type: 'sum',
      },
      {
        enabled: true,
        id: '5',
        params: {
          customLabel: 'Total violations (apdex + error)',
          field: 'json.duration_s',
          json: std.toString({
            script: |||
              int errors = doc['json.status'].value >= 500 ? 1 : 0;
              int slowRequests = doc['json.duration_s'].value > doc['json.target_duration_s'].value ? 1 : 0;
              return errors + slowRequests;
            |||,
          }),
        },
        schema: 'metric',
        type: 'sum',
      },
    ],
    orderById='5',
  );

  local sidekiqSplitColumns = ['json.class.keyword'];

  local sidekiqErrorsTable = elasticsearchLinks.buildElasticTableFailureCountVizURL(
    'sidekiq', featureCategoryFilters, splitSeries=sidekiqSplitColumns, timeRange=timeFrame
  );

  local urgencySplit = {
    type: 'filters',
    schema: 'split',
    params: {
      filters: sidekiqDurationTableFilters,
    },
  };
  local doneFilter = matching.matchers({
    'json.job_status': 'done',
  });

  local sidekiqApdexTables = elasticsearchLinks.buildElasticTableCountVizURL(
    'sidekiq', featureCategoryFilters + doneFilter, splitSeries=[urgencySplit] + sidekiqSplitColumns, timeRange=timeFrame
  );

  basic.text(
    title='Failure log links',
    mode='markdown',
    content=|||
      ##### [Rails Requests Apdex](%(railsRequestsApdexLink)s): slow requests

      This shows the number of requests exceeding the request duration thresholds
      configured per endpoint over the past 7 days.

      The threshold depends on the [configurable request urgency](%(requestUrgencyLink)s).

      ##### [Puma Errors](%(pumaErrorsLink)s): failing requests

      This shows the number of Rails requests that failed per endpoint over
      the past 7 days.

      ##### <a href="%(allRequestViolations)s" target="_blank">All request violations</a>: slow requests + failing requests

      This dashboard shows the endpoints that are violating the apdex.

      ##### [Sidekiq Execution Apdex](%(sidekiqApdexLink)s): slow jobs

      This shows the number of jobs per worker that took longer than their threshold to
      execute over the past 7 days.

      The threshold depends on the [configurable job urgency](%(jobUrgencyLink)s).

      ##### [Sidekiq Execution Errors](%(sidekiqErrorsLink)s): failing jobs

      This shows the number of jobs per worker that failed over the past 7 days.
      This includes retries: if a job with a was retried 3 times, before exhausting
      its retries, this counts as 3 failures towards the budget.

      ##### <a href="%(allJobsViolations)s" target="_blank">All Sidekiq job violations</a>: slow jobs + failing jobs

      This dashboard shows the jobs that are violating the apdex.
    ||| % {
      railsRequestsApdexLink: railsRequestsApdexTable,
      requestUrgencyLink: 'https://docs.gitlab.com/ee/development/application_slis/rails_request.html#adjusting-request-urgency',
      pumaErrorsLink: pumaErrorsTable,
      allRequestViolations: 'https://dashboards.gitlab.net/d/general-application-sli-violations/general-application-sli-violations?orgId=1&var-component=rails_request&from=${__from}&to=${__to}&var-stage_group=' + stageGroup,
      sidekiqErrorsLink: sidekiqErrorsTable,
      sidekiqApdexLink: sidekiqApdexTables,
      jobUrgencyLink: 'https://docs.gitlab.com/ee/development/application_slis/sidekiq_execution.html#adjusting-job-urgency',
      allJobsViolations: 'https://dashboards.gitlab.net/d/general-application-sli-violations/general-application-sli-violations?orgId=1&var-component=sidekiq_execution&from=${__from}&to=${__to}&var-stage_group=' + stageGroup,
    },
  );

{
  init(queries, slaTarget, range):: {
    availabilityStatPanel(group)::
      availabilityStatPanel(queries, slaTarget, range, group),
    errorBudgetStatusPanel(group)::
      errorBudgetStatusPanel(queries, slaTarget, range, group),
    availabilityTargetStatPanel(group)::
      availabilityTargetStatPanel(queries, slaTarget, range, group),
    timeSpentStatPanel(group)::
      timeSpentStatPanel(queries, slaTarget, range, group),
    timeRemainingStatPanel(group)::
      timeRemainingStatPanel(queries, slaTarget, range, group),
    timeRemainingTargetStatPanel(group)::
      timeRemainingTargetStatPanel(queries, slaTarget, range, group),
    timeSpentTargetPanel(group)::
      timeSpentTargetStatPanel(queries, slaTarget, range, group),
    timeSpentTargetStatPanel(group)::
      timeSpentTargetStatPanel(queries, slaTarget, range, group),
    explanationPanel(group)::
      explanationPanel(slaTarget, range, group),
    violationRatePanel(group)::
      violationRatePanel(queries, group),
    violationRateExplanation:: violationRateExplanation,
    logLinks:: logLinks,
  },
}
