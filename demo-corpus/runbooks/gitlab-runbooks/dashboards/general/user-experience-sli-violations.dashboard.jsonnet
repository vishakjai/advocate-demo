local errorBudgetUtils = import '../../libsonnet/stage-groups/error-budget/utils.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local prebuiltTemplates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectorHelper = import 'promql/selectors.libsonnet';
local userExperienceSlIs = import 'stage-groups/user-experience-sli/queries.libsonnet';

local envSelector = {
  stage: '$stage',
  env: '$environment',
};

local groupSelector = {
  product_stage: { re: '$product_stage' },
  stage_group: { re: '$stage_group' },
};

local queries = userExperienceSlIs.init('$__range');

local aggregationLabels = [
  'user_experience_id',
  'urgency',
  'feature_category',
  'stage_group',
];

local selectors = envSelector + groupSelector;

local opsRate = queries.opsRate(selectors, aggregationLabels);

local opsRateWithFallback =
  |||
    %(ops)s
    or on (user_experience_id, feature_category, urgency)
    0 * gitlab:user_experience_sli:info{%(groupSelectors)s}
  ||| % {
    groupSelectors: selectorHelper.serializeHash(groupSelector),
    ops: errorBudgetUtils.rateToOperationCount(opsRate),
  };

local drilldownTable =
  panel.table(
    styles=null,
    queries=[
      opsRateWithFallback,
      queries.apdexRatio(selectors, aggregationLabels),
      queries.errorRatio(selectors, aggregationLabels),
    ],
    transformations=[
      {
        id: 'merge',
      },
      {
        id: 'renameByRegex',
        options: {
          regex: 'Value #A',
          renamePattern: 'operations',
        },
      },
      {
        id: 'renameByRegex',
        options: {
          regex: 'Value #B',
          renamePattern: 'apdex',
        },
      },
      {
        id: 'renameByRegex',
        options: {
          regex: 'Value #C',
          renamePattern: 'errors',
        },
      },
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
            env: true,
          },
          indexByName: {
            user_experience_id: 1,
            urgency: 2,
            feature_category: 3,
            stage_group: 4,
            operations: 5,
            apdex: 6,
            errors: 7,
          },
        },
      },
    ],
  ) + {
    options: {
      sortBy: [
        { displayName: 'operations', desc: true },
      ],
    },
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'feature_category',
          },
          properties: [
            {
              id: 'custom.width',
              value: 300,
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'stage_group',
          },
          properties: [
            {
              id: 'custom.width',
              value: 300,
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'operations',
          },
          properties: [
            {
              id: 'custom.width',
              value: 120,
            },
            {
              id: 'unit',
              value: 'locale',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'apdex',
          },
          properties: [
            {
              id: 'custom.width',
              value: 120,
            },
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
            options: 'errors',
          },
          properties: [
            {
              id: 'custom.width',
              value: 120,
            },
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
                  { color: 'green', value: null },
                  { color: 'red', value: 0.0005 },
                ],
              },
            },
          ],
        },
      ],
    },
  };

basic.dashboard(
  'User Experience SLI Violations',
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
        panelTitle='Aggregated User Experience SLIs Combined Success Ratio',
        query=queries.combinedRatio(selectors, []),
        decimals=2,
        unit='percentunit',
        color=[
          { color: 'red', value: null },
          { color: 'green', value: 0.9995 },
        ]
      ),
      basic.statPanel(
        title='',
        panelTitle='Aggregated User Experience SLIs Apdex',
        query=queries.apdexRatio(selectors, []),
        decimals=2,
        unit='percentunit',
        color=[
          { color: 'red', value: null },
          { color: 'green', value: 0.9995 },
        ]
      ),
      basic.statPanel(
        title='',
        panelTitle='Aggregated User Experience SLIs Error Ratio',
        query=queries.errorRatio(selectors, []),
        decimals=2,
        unit='percentunit',
        color=[
          { color: 'green', value: null },
          { color: 'red', value: 0.0005 },
        ]
      ),
    ], cols=3, rowHeight=5, startRow=100
  )
)
.addPanels(
  layout.rowGrid(
    'User Experience SLIs',
    [drilldownTable],
    collapse=false,
    rowHeight=10,
    startRow=200,
  )
)
.trailer()
