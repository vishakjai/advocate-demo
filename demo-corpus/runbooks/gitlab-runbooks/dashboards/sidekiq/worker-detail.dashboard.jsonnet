local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local link = grafana.link;
local template = grafana.template;
local sidekiqHelpers = import 'services/lib/sidekiq-helpers.libsonnet';
local seriesOverrides = import 'grafana/series_overrides.libsonnet';
local row = grafana.row;
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local issueSearch = import 'gitlab-dashboards/issue_search.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local sidekiq = import 'sidekiq.libsonnet';
local recordingRuleRegistry = (import 'gitlab-metrics-config.libsonnet').recordingRuleRegistry;
local panel = import 'grafana/time-series/panel.libsonnet';
local override = import 'grafana/time-series/override.libsonnet';

local selector = {
  environment: '$environment',
  type: 'sidekiq',
  stage: '$stage',
  worker: { re: '$worker' },
};

local transactionSelector = {
  environment: '$environment',
  type: 'sidekiq',
  stage: '$stage',
  endpoint_id: { re: '$worker' },  //gitlab_transaction_* metrics have worker encoded in the endpoint_id label
};

local avgResourceUsageTimeSeries(title, metricName) =
  panel.timeSeries(
    title=title,
    query=|||
      sum by (worker) (rate(%(metricName)s_sum{%(selector)s}[$__interval]))
      /
      sum by (worker) (
        rate(sidekiq_jobs_completion_count{%(selector)s}[$__interval])
      )
    ||| % {
      selector: selectors.serializeHash(selector),
      metricName: metricName,
    },
    legendFormat='{{ worker }}',
    format='short',
    yAxisLabel='Duration',
  );

local latencyKibanaViz(index, title, percentile) = sidekiq.latencyKibanaViz(index, title, 'class', percentile, templateField='worker');

local recordingRuleRateQuery(recordingRule, selector, aggregator) =
  |||
    sum by (%(aggregator)s) (
      %(recordingRule)s{%(selector)s}
    )
  ||| % {
    aggregator: aggregator,
    selector: selectors.serializeHash(selector),
    recordingRule: recordingRule,
  };

local enqueueCountTimeseries(title, aggregators, legendFormat) =
  panel.timeSeries(
    title=title,
    query=recordingRuleRateQuery(
      recordingRuleRegistry.recordingRuleNameFor('sidekiq_enqueued_jobs_total', '5m'),
      'environment="$environment", worker=~"$worker"',
      aggregators
    ),
    legendFormat=legendFormat,
  );

local rpsTimeseries(title, aggregators, legendFormat) =
  panel.timeSeries(
    title=title,
    query=recordingRuleRateQuery('application_sli_aggregation:sidekiq_execution:ops:rate_5m', 'environment="$environment", worker=~"$worker"', aggregators),
    legendFormat=legendFormat,
  );

local errorRateTimeseries(title, aggregators, legendFormat) =
  panel.timeSeries(
    title=title,
    query=recordingRuleRateQuery('application_sli_aggregation:sidekiq_execution:error:rate_5m', 'environment="$environment", worker=~"$worker"', aggregators),
    legendFormat=legendFormat,
  );

local elasticFilters = [matching.matchFilter('json.stage.keyword', '$stage')];
local elasticQueries = ['json.worker.keyword:${worker:lucene}'];

local elasticsearchLogSearchDataLink = {
  url: elasticsearchLinks.buildElasticDiscoverSearchQueryURL('sidekiq', elasticFilters, elasticQueries),
  title: 'ElasticSearch: Sidekiq logs',
  targetBlank: true,
};

basic.dashboard(
  'Worker Detail',
  tags=['type:sidekiq', 'detail'],
)
.addTemplate(templates.stage)
.addTemplate(template.new(
  'worker',
  '$PROMETHEUS_DS',
  'label_values(application_sli_aggregation:sidekiq_execution:ops:rate_1h{environment="$environment", type="sidekiq"}, worker)',
  current='PostReceive',
  refresh='load',
  sort=1,
  multi=true,
  includeAll=true,
  allValues='.*',
))
.addPanels(
  layout.grid([
    basic.labelStat(
      query=|||
        label_replace(
          topk by (worker) (1, sum(rate(sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker"}[$__range])) by (worker, %(label)s)),
          "%(label)s", "%(default)s", "%(label)s", ""
        )
      ||| % {
        label: attribute.label,
        default: attribute.default,
      },
      title='Worker Attribute: ' + attribute.title,
      color=attribute.color,
      legendFormat='{{ %s }} ({{ worker }})' % [attribute.label],
      links=attribute.links
    )
    for attribute in [{
      label: 'urgency',
      title: 'Urgency',
      color: 'yellow',
      default: 'unknown',
      links: [],
    }, {
      label: 'feature_category',
      title: 'Feature Category',
      color: 'blue',
      default: 'unknown',
      links: [],
    }, {
      label: 'shard',
      title: 'Shard',
      color: 'orange',
      default: 'unknown',
      links: [{
        title: 'Sidekiq Shard Detail: ${__field.label.shard}',
        url: '/d/sidekiq-shard-detail/sidekiq-shard-detail?orgId=1&var-shard=${__field.label.shard}&var-environment=${environment}&var-stage=${stage}&${__url_time_range}',
      }],
    }, {
      label: 'external_dependencies',
      title: 'External Dependencies',
      color: 'green',
      default: 'none',
      links: [],
    }, {
      label: 'boundary',
      title: 'Resource Boundary',
      color: 'purple',
      default: 'none',
      links: [],
    }]
  ] + [
    basic.statPanel(
      'Max Queuing Duration SLO',
      'Max Queuing Duration SLO',
      'light-red',
      |||
        vector(NaN) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", urgency="throttled"}
        or
        vector(%(lowUrgencySLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", urgency="low"}
        or
        vector(%(urgentSLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", urgency="high"}
      ||| % {
        lowUrgencySLO: sidekiqHelpers.slos.lowUrgency.queueingDurationSeconds,
        urgentSLO: sidekiqHelpers.slos.urgent.queueingDurationSeconds,
      },
      legendFormat='{{ worker }}',
      unit='s',
    ),
    basic.statPanel(
      'Max Execution Duration SLO',
      'Max Execution Duration SLO',
      'red',
      |||
        vector(%(throttledSLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", urgency="throttled"}
        or
        vector(%(lowUrgencySLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", urgency="low"}
        or
        vector(%(urgentSLO)f) and on () sidekiq_running_jobs{environment="$environment", type="sidekiq", stage="$stage", worker=~"$worker", urgency="high"}
      ||| % {
        throttledSLO: sidekiqHelpers.slos.throttled.executionDurationSeconds,
        lowUrgencySLO: sidekiqHelpers.slos.lowUrgency.executionDurationSeconds,
        urgentSLO: sidekiqHelpers.slos.urgent.executionDurationSeconds,
      },
      legendFormat='{{ worker }}',
      unit='s',
    ),
    basic.labelStat(
      title='Stage Group',
      color='light-green',
      query=|||
        application_sli_aggregation:sidekiq_execution:ops:rate_1h{env="$environment", worker=~"$worker"} *
        on (feature_category) group_left(stage_group) gitlab:feature_category:stage_group:mapping * 0
      |||,
      legendFormat='{{ stage_group }}',
    ),
  ], cols=8, rowHeight=4)
  +
  [row.new(title='🌡 Worker Key Metrics') { gridPos: { x: 0, y: 100, w: 24, h: 1 } }]
  +
  layout.grid(
    [
      panel.apdexTimeSeries(
        stableId='queue-apdex',
        title='Queue Apdex',
        description='Queue apdex monitors the percentage of jobs that are dequeued within their queue threshold. Higher is better. Different jobs have different thresholds.',
        query=|||
          sum by (worker) (
            clamp_max(
              (application_sli_aggregation:sidekiq_queueing:apdex:success:rate_5m{environment="$environment", worker=~"$worker"} >= 0)
              /
              (application_sli_aggregation:sidekiq_queueing:apdex:weight:score_5m{environment="$environment", worker=~"$worker"} >= 0)
            , 1)
          )
        |||,
        yAxisLabel='% Jobs within Max Queuing Duration SLO',
        legendFormat='{{ worker }} queue apdex',
        legend_show=true,
      )
      .addSeriesOverride(override.goldenMetric('/.* queue apdex$/'))
      .addDataLink(elasticsearchLogSearchDataLink)
      .addDataLink({
        url: elasticsearchLinks.buildElasticLinePercentileVizURL('sidekiq', elasticFilters, elasticQueries, 'json.queue_duration_s'),
        title: 'ElasticSearch: queue latency visualization',
        targetBlank: true,
      }),
      panel.apdexTimeSeries(
        stableId='execution-apdex',
        title='Execution Apdex',
        description='Execution apdex monitors the percentage of jobs that run within their execution (run-time) threshold. Higher is better. Different jobs have different thresholds.',
        query=|||
          sum by (worker) (
            clamp_max(
              (application_sli_aggregation:sidekiq_execution:apdex:success:rate_5m{environment="$environment", worker=~"$worker"} >= 0)
              /
              (application_sli_aggregation:sidekiq_execution:apdex:weight:score_5m{environment="$environment", worker=~"$worker"} >= 0)
            , 1)
          )
        |||,
        yAxisLabel='% Jobs within Max Execution Duration SLO',
        legendFormat='{{ worker }} execution apdex',
        legend_show=true,
      )
      .addSeriesOverride(override.goldenMetric('/.* execution apdex$/'))
      .addDataLink(elasticsearchLogSearchDataLink)
      .addDataLink({
        url: elasticsearchLinks.buildElasticLinePercentileVizURL('sidekiq', elasticFilters, elasticQueries, 'json.duration_s'),
        title: 'ElasticSearch: execution latency visualization',
        targetBlank: true,
      }),
      panel.timeSeries(
        stableId='request-rate',
        title='Execution Rate (RPS)',
        description='Jobs executed per second',
        query=|||
          sum by (worker) (application_sli_aggregation:sidekiq_execution:ops:rate_5m{environment="$environment", worker=~"$worker"})
        |||,
        legendFormat='{{ worker }} rps',
        format='ops',
        yAxisLabel='Jobs per Second',
      )
      .addSeriesOverride(override.goldenMetric('/.* rps$/'))
      .addDataLink(elasticsearchLogSearchDataLink)
      .addDataLink({
        url: elasticsearchLinks.buildElasticLineCountVizURL('sidekiq', elasticFilters, elasticQueries),
        title: 'ElasticSearch: RPS visualization',
        targetBlank: true,
      }),
      panel.percentageTimeSeries(
        stableId='error-ratio',
        title='Error Ratio',
        description='Percentage of jobs that fail with an error. Lower is better.',
        query=|||
          sum by (worker) (
            (application_sli_aggregation:sidekiq_execution:error:rate_5m{environment="$environment", worker=~"$worker"} >= 0)
          )
          /
          sum by (worker) (
            (application_sli_aggregation:sidekiq_execution:ops:rate_5m{environment="$environment", worker=~"$worker"} >= 0)
          )
        |||,
        legendFormat='{{ worker }} error ratio',
        yAxisLabel='Error Percentage',
        legend_show=true,
      )
      .addSeriesOverride(override.goldenMetric('/.* error ratio$/'))
      .addDataLink(elasticsearchLogSearchDataLink)
      .addDataLink({
        url: elasticsearchLinks.buildElasticLineCountVizURL(
          'sidekiq',
          elasticFilters + [matching.matchFilter('json.job_status', 'fail')],
          elasticQueries
        ),
        title: 'ElasticSearch: errors visualization',
        targetBlank: true,
      }),
    ],
    cols=4,
    rowHeight=8,
    startRow=101,
  )
  +
  layout.rowGrid(
    'Enqueuing (rate of jobs enqueuing)',
    [
      enqueueCountTimeseries('Jobs Enqueued', aggregators='worker', legendFormat='{{ worker }}'),
      enqueueCountTimeseries('Jobs Enqueued per Service', aggregators='type, worker', legendFormat='{{ worker }} - {{ type }}'),
      panel.timeSeries(
        stableId='enqueued-by-scheduling-type',
        title='Jobs Enqueued by Schedule',
        description='Enqueue events separated by immediate (destined for execution) vs delayed (destined for ScheduledSet) scheduling.',
        query=|||
          sum by (queue, scheduling) (
            rate(sidekiq_enqueued_jobs_total{environment="$environment", stage="$stage", worker=~"$worker"}[$__interval])
            )
        |||,
        legendFormat='{{ queue }} - {{ scheduling }}',
      ),
      panel.queueLengthTimeSeries(
        stableId='queue-length',
        title='Queue length',
        description='The number of unstarted jobs in a queue (capped at 1000 at scrape time for performance reasons)',
        query=|||
          max by (name) (max_over_time(sidekiq_enqueued_jobs{environment="$environment", name=~"$worker"}[$__interval]) and on(fqdn) (redis_connected_slaves != 0)) or on () label_replace(vector(0), "name", "$worker", "name", "")
        |||,
        legendFormat='{{ name }}',
        format='short',
        interval='1m',
        intervalFactor=3,
        yAxisLabel='',
      ),
    ],
    startRow=201,
  )
  +
  layout.rowGrid('Queue Time & Execution Time', [
    grafana.text.new(
      title='Queue Time - time spend queueing',
      mode='markdown',
      description='Estimated queue time, between when the job is enqueued and executed. Lower is better.',
      content=toolingLinks.generateMarkdown([
        latencyKibanaViz('sidekiq_queueing_viz_by_worker', '📈 Kibana: Sidekiq queue time p95 percentile latency aggregated (split by worker)', 95),
      ])
    ),
    grafana.text.new(
      title='Individual Execution Time - time taken for individual jobs to complete',
      mode='markdown',
      description='The duration, once a job starts executing, that it runs for, by shard. Lower is better.',
      content=toolingLinks.generateMarkdown([
        latencyKibanaViz('sidekiq_execution_viz_by_worker', '📈 Kibana: Sidekiq execution time p95 percentile latency aggregated (split by worker)', 95),
      ])
    ),
  ], startRow=301, rowHeight=5)
  +
  layout.rowGrid('Execution RPS (the rate at which jobs are completed after dequeue)', [
    rpsTimeseries('RPS', aggregators='worker', legendFormat='{{ worker }}'),
  ], startRow=501)
  +
  layout.rowGrid(
    'Error Rate (the rate at which jobs fail)',
    [
      errorRateTimeseries('Errors', aggregators='worker', legendFormat='{{ worker }}'),
      panel.timeSeries(
        title='Dead Jobs',
        query=|||
          sum by (worker) (
            increase(sidekiq_jobs_dead_total{%(selector)s}[5m])
          )
        ||| % {
          selector: selectors.serializeHash(selector),
        },
        legendFormat='{{ worker }}',
      ),
    ],
    startRow=601,
  )
  +
  [
    row.new(title='Resource Usage') { gridPos: { x: 0, y: 700, w: 24, h: 1 } },
  ] +
  layout.grid(
    [
      avgResourceUsageTimeSeries('Average CPU Time', 'sidekiq_jobs_cpu_seconds'),
      avgResourceUsageTimeSeries('Average Gitaly Time', 'sidekiq_jobs_gitaly_seconds'),
      avgResourceUsageTimeSeries('Average Database Time', 'sidekiq_jobs_db_seconds'),
    ], cols=3, startRow=702
  )
  +
  layout.grid(
    [
      avgResourceUsageTimeSeries('Average Redis Time', 'sidekiq_redis_requests_duration_seconds'),
      avgResourceUsageTimeSeries('Average Elasticsearch Time', 'sidekiq_elasticsearch_requests_duration_seconds'),
    ], cols=3, startRow=703
  )
  +
  layout.rowGrid(
    'SQL',
    [
      panel.multiTimeSeries(
        stableId='total-sql-queries-rate',
        title='Total SQL Queries Rate',
        format='ops',
        queries=[
          {
            query: |||
              sum by (endpoint_id) (
                rate(
                  gitlab_transaction_db_count_total{%(transactionSelector)s}[$__interval]
                )
              )
            ||| % { transactionSelector: selectors.serializeHash(transactionSelector) },
            legendFormat: '{{ endpoint_id }} - total',
          },
          {
            query: |||
              sum by (endpoint_id) (
                rate(
                  gitlab_transaction_db_primary_count_total{%(transactionSelector)s}[$__interval]
                )
              )
            ||| % { transactionSelector: selectors.serializeHash(transactionSelector) },
            legendFormat: '{{ endpoint_id }} - primary',
          },
          {
            query: |||
              sum by (endpoint_id) (
                rate(
                  gitlab_transaction_db_replica_count_total{%(transactionSelector)s}[$__interval]
                )
              )
            ||| % { transactionSelector: selectors.serializeHash(transactionSelector) },
            legendFormat: '{{ endpoint_id }} - replica',
          },
        ]
      ),
      panel.timeSeries(
        stableId='sql-transaction',
        title='SQL Transactions Rate',
        query=|||
          sum by (endpoint_id) (
            rate(gitlab_database_transaction_seconds_count{%(transactionSelector)s}[$__interval])
          )
        ||| % { transactionSelector: selectors.serializeHash(transactionSelector) },
        legendFormat='{{ endpoint_id }}',
      ),
      panel.multiTimeSeries(
        stableId='sql-transaction-holding-duration',
        title='SQL Transaction Holding Duration',
        format='s',
        queries=[
          {
            query: |||
              sum(rate(gitlab_database_transaction_seconds_sum{%(transactionSelector)s}[$__interval])) by (endpoint_id)
              /
              sum(rate(gitlab_database_transaction_seconds_count{%(transactionSelector)s}[$__interval])) by (endpoint_id)
            ||| % { transactionSelector: selectors.serializeHash(transactionSelector) },
            legendFormat: '{{ endpoint_id }} - p50',
          },
          {
            query: |||
              histogram_quantile(0.95, sum(rate(gitlab_database_transaction_seconds_bucket{%(transactionSelector)s}[$__interval])) by (endpoint_id, le))
            ||| % { transactionSelector: selectors.serializeHash(transactionSelector) },
            legendFormat: '{{ endpoint_id }} - p95',
          },
        ],
      ),
    ],
    startRow=750
  )
  +
  layout.rowGrid('Skipped Jobs', [
    panel.timeSeries(
      stableId='jobs-skipped',
      title='Rate of Jobs Skipped',
      description='Jobs skipped (dropped/deferred) intentionally via feature flag `drop_sidekiq_jobs_<worker_name>` or `run_sidekiq_jobs_<worker_name>`',
      query=|||
        sum by (environment, worker, action, reason)  (
          rate(
            sidekiq_jobs_skipped_total{environment="$environment", worker=~"$worker"}[$__interval]
            )
          )
          > 0
      |||,
      legendFormat='{{ worker }} - {{ action }} by {{ reason }}',
    ),
  ], startRow=801)
)
.trailer()
+ {
  links+:
    platformLinks.triage +
    platformLinks.services +
    [
      platformLinks.dynamicLinks('Sidekiq Detail', 'type:sidekiq'),
      link.dashboards(
        'Find issues for $worker',
        '',
        type='link',
        targetBlank=true,
        url=issueSearch.buildInfraIssueSearch(labels=['Service::Sidekiq'], search='$worker')
      ),
    ],
}
