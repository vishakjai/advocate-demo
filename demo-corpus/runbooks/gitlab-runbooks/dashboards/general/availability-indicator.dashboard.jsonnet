local errorBudget = import '../../libsonnet/stage-groups/error_budget.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local prebuiltTemplates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local baseSelector = {
  monitor: 'global',
  environment: '$environment',
};

local groupSelector = {
  product_stage: { re: '$product_stage' },
  stage_group: { re: '$stage_group' },
};

local queries = errorBudget('$__range').queries;
local overallAvailabilityQuery = queries.errorBudgetRatio(baseSelector + groupSelector);
local groupAvailabilityQuery =
  |||
    sum by (product_stage, stage_group) (
      last_over_time(gitlab:stage_group:availability:ratio_28d{%(selectorHash)s}[$__range])
    )
  ||| % {
    selectorHash: selectors.serializeHash(baseSelector + groupSelector),
  };

local groupTrafficShareQuery =
  |||
    sum by (product_stage, stage_group) (
      last_over_time(gitlab:stage_group:traffic_share:ratio_28d{%(selectorHash)s}[$__range])
    )
  ||| % {
    selectorHash: selectors.serializeHash(baseSelector + groupSelector),
  };

local groupAvailabilities =
  panel.table(
    title='Availabilities',
    styles=null,
    queries=[
      groupAvailabilityQuery,
      groupTrafficShareQuery,
    ],
    transformations=[
      {
        id: 'merge',
      },
      {
        id: 'renameByRegex',
        options: {
          regex: 'Value #A',
          renamePattern: 'Availability',
        },
      },
      {
        id: 'renameByRegex',
        options: {
          regex: 'Value #B',
          renamePattern: 'Traffic %',
        },
      },
      {
        id: 'renameByRegex',
        options: {
          regex: 'stage_group',
          renamePattern: 'Group',
        },
      },
      {
        id: 'renameByRegex',
        options: {
          regex: 'product_stage',
          renamePattern: 'Stage',
        },
      },
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
            env: true,
            feature_category: true,
          },
          indexByName: {
            Group: 1,
            Stage: 2,
            Availability: 3,
          },
        },
      },
    ],
  ) + {
    options: {
      sortBy: [
        { displayName: 'Traffic %', desc: true },
        { displayName: 'Availability', asc: true },
      ],
    },
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'Availability',
          },
          properties: [
            {
              id: 'unit',
              value: 'percentunit',
            },
            {
              id: 'decimals',
              value: 2,
            },
            {
              id: 'custom.cellOptions',
              value: {
                type: 'color-text',
              },
            },
            {
              id: 'color.mode',
              value: 'thresholds',
            },
            {
              id: 'thresholds',
              value: {
                steps: [
                  { color: 'red', value: null },
                  { color: 'green', value: 0.9995 },
                ],
              },
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Traffic %',
          },
          properties: [
            {
              id: 'unit',
              value: 'percentunit',
            },
            {
              id: 'decimals',
              value: 2,
            },
            {
              id: 'custom.cellOptions',
              value: {
                type: 'color-text',
              },
            },
            {
              id: 'color.mode',
              value: 'thresholds',
            },
            {
              id: 'thresholds',
              value: {
                steps: [
                  { color: 'grey', value: null },
                  { color: 'white', value: 0.0001 },
                ],
              },
            },
          ],
        },
      ],
    },
  };

local overBudgetQuery = queries.errorBudgetGroupsOverBudget(baseSelector + groupSelector);

local overBudgetThreshold = '3';

basic.dashboard(
  'Availability indicator',
  tags=[],
  time_from='now-7d/m',
  time_to='now/m',
).addTemplate(prebuiltTemplates.environment)
.addTemplate(prebuiltTemplates.stage)
.addTemplate(prebuiltTemplates.productStage())
.addTemplate(prebuiltTemplates.stageGroup())
.addPanels(
  layout.grid(
    [
      basic.statPanel(
        title='',
        panelTitle='Error budget for all groups',
        query=overallAvailabilityQuery,
        decimals=2,
        unit='percentunit',
        color=[
          { color: 'red', value: null },
          { color: 'green', value: 0.9995 },
        ]
      ),
      panel.basic(
        'Teams over budget target',
        legend_show=false,
      )
      .addTarget(
        target.prometheus(overBudgetThreshold, legendFormat='Target')
      )
      .addTarget(
        target.prometheus(overBudgetQuery, legendFormat='Teams Over Budget'),
      ),
    ],
    cols=2,
    rowHeight=10,
    startRow=100,
  )
)
.addPanels(
  layout.rowGrid(
    'Error budget by groups',
    [groupAvailabilities],
    rowHeight=10,
    startRow=200,
  ),
)
.trailer()
