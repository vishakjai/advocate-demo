local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local totalNumberOfJobsFailed = 'count(count_over_time(delivery_deployment_job_duration_seconds{job_status="failed"}[$__range]))';
local incompleteDeploymentsQuery = 'sum by (version) (max_over_time(delivery_deployment_completed[$__range])) < 4';
local numberOfAutoDeployJobRetriesByJobQuery = 'sort_desc(sum(increase(delivery_webhooks_auto_deploy_job_retries[$__range])) by (project, job_name) != 0)';
local numberOfAutoDeployJobRetriesQuery = 'sort_desc(sum(increase(delivery_webhooks_auto_deploy_job_retries[$__range])) by (project) != 0)';
local secondsLostBetweenRetriesQuery = 'sum by(job_name)(increase(delivery_webhooks_auto_deploy_job_failure_lost_seconds[$__range]) != 0)';
local taggedPackagesTotalByTypesQuery = 'sort_desc(sum(increase(delivery_packages_tagging_total[$__range])) by (pkg_type,security))';

local styles = [
  {  // remove decimal points
    type: 'number',
    pattern: 'Value',
    decimals: 0,
    mappingType: 1,
  },
];

// Adding the unit to the styles array
local timeLostUnit = [
  styles[0] {
    unit: 's',
  },
];

local totalJobsFailedStatPanel =
  basic.statPanel(
    title='',
    panelTitle='Total Number of Job Failures',
    colorMode='value',
    format='table',
    query=totalNumberOfJobsFailed,
    color=[
      { color: 'white', value: null },
    ],
  );

local autoDeployJobRetriesTable =
  panel.table(
    title='Number of auto-deploy job retries per Project',
    description="This table shows the number of auto-deploy job retries per project for the duration chosen. For further insight, refer to the 'Number of auto-deploy retries per job' table, which separates the retries by job name",
    styles=null,
    queries=[numberOfAutoDeployJobRetriesQuery],
    sort=4,  // numerically descending
    transformations=[
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
          },
          renameByName: {
            project: 'Project',
            Value: 'Total Retries',
          },
        },
      },
    ],
  ) {
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'Value',
          },
          properties: [
            {  // remove decimals
              id: 'decimals',
              value: 0,
            },
          ],
        },
      ],
    },
  };

local autoDeployJobRetriesByJobTable =
  panel.table(
    title='Number of auto-deploy retries per job',
    description='This table shows the number of auto-deploy job retries per project and per job for the duration chosen.',
    styles=styles,
    queries=[numberOfAutoDeployJobRetriesByJobQuery],
    sort=4,  // numerically descending
    transformations=[
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
          },
          renameByName: {
            project: 'Project',
            Value: 'Total Retries',
            job_name: 'Job Name',
          },
        },
      },
    ],
  ) {
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'Value',
          },
          properties: [
            {  // remove decimals
              id: 'decimals',
              value: 0,
            },
          ],
        },
      ],
    },
  };

local taggedReleasesByTypeTable =
  panel.table(
    title='Number of Tagged Releases by Type',
    styles=null,
    query=taggedPackagesTotalByTypesQuery,
    transformations=[
      {  // concatenate the columnns for 'pkg_type' and 'security' to create a new column 'Release Type'
        id: 'calculateField',
        alias: 'Release Type',
        binary: {
          left: 'pkg_type',
          reducer: 'sum',
          right: 'security',
        },
        mode: 'reduceRow',
        reduce: {
          include: ['pkg_type', 'security'],
          reducer: 'allValues',
        },
        options: {
          mode: 'reduceRow',
          reduce: {
            reducer: 'allValues',
            include: ['pkg_type', 'security'],
          },
          replaceFields: false,
          alias: 'Release Type',
        },
      },
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
            pkg_type: true,
            security: true,
          },
          indexByName: {
            'Release Type': 0,
            Value: 1,
            Time: 2,
            pkg_type: 3,
            security: 4,
          },
        },
      },
      {  // Exclude invalid release types variations
        id: 'filterByValue',
        options: {
          filters: [
            {
              config: {
                id: 'regex',
                options: {
                  value: '^auto_deploy,(?!$|no$).*',
                },
              },
              fieldName: 'Release Type',
            },
            {
              config: {
                id: 'regex',
                options: {
                  value: '^monthly,(?!no$).*',
                },
              },
              fieldName: 'Release Type',
            },
            {
              config: {
                id: 'regex',
                options: {
                  value: '^rc,(?!no$).*',
                },
              },
              fieldName: 'Release Type',
            },
            {
              config: {
                id: 'regex',
                options: {
                  value: '^security,(?!$).*',
                },
              },
              fieldName: 'Release Type',
            },
          ],
          match: 'any',
          type: 'exclude',
        },
      },
    ],
  ) {
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'Release Type',
          },
          properties: [
            {  // User-friendly release types
              id: 'mappings',
              value: [
                {
                  type: 'value',
                  options: {
                    'auto_deploy,no': {
                      text: 'Auto Deploy',
                    },
                    'auto_deploy,': {
                      text: 'Auto Deploy (deprecated)',  // deprecate once this value hits 0
                    },
                    'rc,no': {
                      text: 'RC',
                    },
                    'patch,no': {
                      text: 'Regular Patch',
                    },
                    'patch,critical': {
                      text: 'Critical Security Patch',
                    },
                    'patch,regular': {
                      text: 'Regular Security Patch',
                    },
                    'monthly,no': {
                      text: 'Monthly',
                    },
                  },
                },
              ],
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Value',
          },
          properties: [
            {  // remove decimals
              id: 'decimals',
              value: 0,
            },
          ],
        },
      ],
    },
  };

local incompleteDeploymentsTable =
  panel.table(
    title='Incomplete Auto-Deployment Versions',
    description='Remember to not count the currently deploying version. Because of of how the delivery_deployment_completed metric works, it will always include the last one that is still deploying by the end of this query range (at the top).',
    styles=null,
    instant=true,
    query=incompleteDeploymentsQuery,
    transformations=[
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
            Value: true,
          },
          indexByName: {},
          renameByName: {
            version: 'versions (read description)',
          },
        },
      },
    ],
  );

local incompleteDeploymentsStatPanel =
  basic.statPanel(
    title='',
    panelTitle='Total Number of Incomplete Auto-Deployments',
    description='Because of of how the delivery_deployment_completed metric works, it will always include the last one that is still deploying by the end of this query range (at the top). That is why this number is 1 less than the number of rows from the Incomplete Auto-Deploy Versions table.',
    colorMode='value',
    format='table',
    query=incompleteDeploymentsQuery,
    color=[
      { color: 'white', value: null },
    ],
    transformations=[
      {
        id: 'organize',
        options: {
          excludeByName: {
            Time: true,
            Value: true,
          },
          indexByName: {},
          renameByName: {},
        },
      },
      {
        id: 'reduce',
        options: {
          reducers: [
            'changeCount',
          ],
          includeTimeField: false,
          labelsToFields: true,
          mode: 'seriesToRows',
        },
      },
    ],
  );

local barGaugePanel(
  title,
  description='',
  fieldColor={},
  fieldLinks=[],
  legendFormat='',
  links=[],
  minVizHeight=30,
  minVizWidth=0,
  orientation='horizontal',
  query='',
  reduceOptions={},
  thresholds={},
  transformations=[],
  unit=''
      ) =
  {
    description: description,
    fieldConfig: {
      values: false,
      defaults: {
        mappings: [],
        thresholds: thresholds,
        color: fieldColor,
        links: fieldLinks,
        unit: unit,
      },
    },
    links: links,
    options: {
      reduceOptions: reduceOptions,
      displayMode: 'basic',
      orientation: orientation,
      showUnfilled: true,
      minVizWidth: minVizWidth,
      minVizHeight: minVizHeight,
    },
    pluginVersion: '9.4.7',
    targets: [promQuery.target(query, format='table', intervalFactor=2, legendFormat=legendFormat, instant=false)],
    title: title,
    type: 'bargauge',
    transformations: transformations,
  };

basic.dashboard(
  'Release Management Toil',
  tags=['release'],
  editable=true,
  time_from='now-7d',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
)

.addPanels(
  layout.rowGrid(
    '🚀 Tagged Releases 🚀',
    [taggedReleasesByTypeTable],
    collapse=false,
    rowHeight=10,
    startRow=0,
  )
)

.addPanels(
  layout.rowGrid(
    'Auto-deploy Deployments Statistics',
    [
      barGaugePanel(
        'Auto-deploy Deployments Pipeline Duration',
        description='For all the auto-deploy pipelines in the time range, display total duration per pipeline',
        fieldColor={
          fixedColor: 'green',
          mode: 'palette-classic',
        },
        fieldLinks=[
          {
            title: 'Deploy version link',
            url: 'https://dashboards.gitlab.net/d/delivery-deployment_metrics/delivery-deployment-metrics?orgId=1&${__url_time_range}&var-deploy_version=${__data.fields.deploy_version}',
          },
        ],
        legendFormat='{{deploy_version}}',
        query='delivery_deployment_pipeline_duration_seconds{project_name="gitlab-org/release/tools", pipeline_name="Coordinator pipeline"}',
        reduceOptions={
          values: 'true',
          calcs: [],
          fields: '/^Value \\(max\\)$/',
        },
        thresholds={
          steps: [
            { color: 'green', value: null },
          ],
        },
        transformations=[
          {
            id: 'groupBy',
            options: {
              fields: {
                Time: {
                  aggregations: ['first'],
                  operation: 'aggregate',
                },
                Value: {
                  aggregations: ['max'],
                  operation: 'aggregate',
                },
                deploy_version: {
                  aggregations: [],
                  operation: 'groupby',
                },
              },
            },
          },
          {
            id: 'sortBy',
            options: {
              fields: {},
              sort: [
                {
                  desc: 'true',
                  field: 'deploy_version',
                },
              ],
            },
          },
        ],
        unit='s',
      ),
    ],
    collapse=false,
    rowHeight=10,
    startRow=100,
  ),
)

.addPanels(
  layout.rowGrid(
    '❌ Incomplete/Failed Deployments ❌',
    [
      incompleteDeploymentsStatPanel,
      incompleteDeploymentsTable,
    ],
    collapse=false,
    rowHeight=10,
    startRow=200,
  )
)

.addPanels(
  layout.rowGrid(
    '❌ Failed Jobs ❌',
    [
      totalJobsFailedStatPanel,
      barGaugePanel(
        'Total Number of Job Failures Per Auto-Deploy Version (25 max)',
        description='For up to 25 latest auto-deploy versions in the time range, display the total number of job failures per version',
        fieldColor={
          fixedColor: 'green',
          mode: 'palette-classic',
        },
        fieldLinks=[
          {
            title: 'Deploy version link',
            url: 'https://dashboards.gitlab.net/d/delivery-deployment_metrics/delivery-deployment-metrics?orgId=1&${__url_time_range}&var-deploy_version=${__data.fields.deploy_version}',
          },
        ],
        legendFormat='{{deploy_version}}',
        query='count by (deploy_version) (sum_over_time(delivery_deployment_job_duration_seconds{job_status="failed"}[$__range]))',
        reduceOptions={
          values: 'true',
          calcs: [],
          fields: '/^Value \\(max\\)$/',
        },
        thresholds={
          steps: [
            { color: 'green', value: null },
          ],
        },
        transformations=[
          {
            id: 'groupBy',
            options: {
              fields: {
                deploy_version: {
                  aggregations: [],
                  operation: 'groupby',
                },
                Value: {
                  aggregations: [
                    'max',
                  ],
                  operation: 'aggregate',
                },
              },
            },
          },
          {
            id: 'sortBy',
            options: {
              fields: {},
              sort: [
                {
                  field: 'deploy_version',
                  desc: true,
                },
              ],
            },
          },
        ],
      ),
    ],
    collapse=false,
    rowHeight=10,
    startRow=300,
  )
)

.addPanels(
  layout.rowGrid(
    '🔄 Auto Deploy Job Retries 🔄',
    [
      autoDeployJobRetriesTable,
      autoDeployJobRetriesByJobTable,
    ],
    collapse=false,
    rowHeight=8,
    startRow=400,
  )
)

.addPanels(
  layout.singleRow([
    panel.table(
      title='Increase in deployment pipeline duration due to retry of failed jobs',
      description='This panel shows how much the deployment pipeline duration was increased by the need to retry failed jobs. For example,\nif a failed job is retried and succeeds after an hour of the failure, the deployment pipeline duration was increased by an hour.',
      styles=timeLostUnit,
      queries=[secondsLostBetweenRetriesQuery],
      sort={
        col: 1,
        desc: true,
      },
      transformations=[
        {
          id: 'organize',
          options: {
            excludeByName: {
              Time: true,
            },
          },
        },
      ],
    ),
  ], rowHeight=8, startRow=500),
)

.trailer()
