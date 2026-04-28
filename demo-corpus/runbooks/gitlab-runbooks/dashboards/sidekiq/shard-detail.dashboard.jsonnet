local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local nodeMetrics = import 'gitlab-dashboards/node_metrics.libsonnet';
local platformLinks = import 'gitlab-dashboards/platform_links.libsonnet';
local railsCommon = import 'gitlab-dashboards/rails_common_graphs.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local row = grafana.row;
local saturationDetail = import 'gitlab-dashboards/saturation_detail.libsonnet';
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';
local link = grafana.link;
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local recordingRuleRegistry = (import 'gitlab-metrics-config.libsonnet').recordingRuleRegistry;
local panel = import 'grafana/time-series/panel.libsonnet';
local threshold = import 'grafana/time-series/threshold.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

local selectors = import 'promql/selectors.libsonnet';

local optimalUtilization = 0.33;
local optimalMargin = 0.10;

local selectorHash = { type: 'sidekiq', environment: '$environment', stage: '$stage', shard: { re: '$shard' } };
local selector = selectors.serializeHash(selectorHash);
local sidekiq = import 'sidekiq.libsonnet';

local workerDetailDataLink = {
  url: '/d/sidekiq-worker-detail?${__url_time_range}&${__all_variables}&var-worker=${__field.label.worker}',
  title: 'Worker Detail: ${__field.labels.worker}',
};

local latencyKibanaViz(index, title, percentile) = sidekiq.latencyKibanaViz(index, title, 'shard', percentile);

local inflightJobsTimeseries(title, aggregator) =
  panel.timeSeries(
    title=title,
    description='The total number of jobs being executed at a single moment for the shard',
    query=|||
      sum(sidekiq_running_jobs{environment="$environment", shard=~"$shard"}) by (%s)
    ||| % [aggregator],
    legendFormat='{{ %s }}' % [aggregator],
    interval='1m',
    intervalFactor=1,
    legend_show=true,
    linewidth=1,
  );

basic.dashboard(
  'Shard Detail',
  tags=['type:sidekiq', 'detail'],
)
.addTemplate(templates.stage)
.addTemplate(templates.shard('sidekiq', '.*'))
.addPanels(
  layout.rowGrid(
    'Queue Lengths - number of jobs queued',
    [
      panel.queueLengthTimeSeries(
        title='Queue Lengths',
        description='The number of unstarted jobs in queues serviced by this shard',
        query=|||
          sum by (queue) (
            (
              label_replace(
                sidekiq_queue_size{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0),
                "queue", "$0", "name", ".*"
              )
            )
            and on (queue)
            (
              max by (queue) (
                %(queueingApdexWeight)s{environment="$environment", shard=~"$shard"} > 0
              )
            )
          )
        ||| % {
          queueingApdexWeight: recordingRuleRegistry.recordingRuleNameFor('gitlab_sli_sidekiq_queueing_apdex_total', '5m'),
        },
        legendFormat='{{ queue }}',
        format='short',
        interval='1m',
        intervalFactor=3,
        yAxisLabel='Jobs',
      )
      .addDataLink(workerDetailDataLink),
      panel.queueLengthTimeSeries(
        title='Aggregate queue length',
        description='The sum total number of unstarted jobs in all queues serviced by this shard',
        query=|||
          sum(
            (
              label_replace(
                sidekiq_queue_size{environment="$environment"} and on(fqdn) (redis_connected_slaves != 0),
                "queue", "$0", "name", ".*"
              )
            )
            and on (queue)
            (
              max by (queue) (
                %(queueingApdexWeight)s{environment="$environment", shard=~"$shard"} > 0
              )
            )
          )
        ||| % {
          queueingApdexWeight: recordingRuleRegistry.recordingRuleNameFor('gitlab_sli_sidekiq_queueing_apdex_total', '5m'),
        },
        legendFormat='Aggregated queue length',
        format='short',
        interval='1m',
        intervalFactor=3,
        yAxisLabel='Jobs',
      ),
    ],
    startRow=101
  )
  +
  layout.rowGrid('Queue Time & Execution Time', [
    grafana.text.new(
      title='Queue Time - time spend queueing',
      mode='markdown',
      description='Estimated queue time, between when the job is enqueued and executed. Lower is better.',
      content=toolingLinks.generateMarkdown([
        latencyKibanaViz('sidekiq_queueing_viz_by_shard', '📈 Kibana: Sidekiq queue time p95 percentile latency (split by shard)', 95),
        latencyKibanaViz('sidekiq_queueing_viz_by_worker', '📈 Kibana: Sidekiq queue time p95 percentile latency aggregated (split by worker)', 95),
        latencyKibanaViz('sidekiq_queueing_viz_by_queue', '📈 Kibana: Sidekiq queue time p95 percentile latency aggregated (split by queue)', 95),
      ])
    ),
    grafana.text.new(
      title='Individual Execution Time - time taken for individual jobs to complete',
      mode='markdown',
      description='The duration, once a job starts executing, that it runs for, by shard. Lower is better.',
      content=toolingLinks.generateMarkdown([
        latencyKibanaViz('sidekiq_execution_viz_by_shard', '📈 Kibana: Sidekiq execution time median latency (split by shard)', 50),
        latencyKibanaViz('sidekiq_execution_viz_by_shard', '📈 Kibana: Sidekiq execution time p95 percentile latency (split by shard)', 95),
        latencyKibanaViz('sidekiq_execution_viz_by_worker', '📈 Kibana: Sidekiq execution time p95 percentile latency aggregated (split by worker)', 95),
        latencyKibanaViz('sidekiq_execution_viz_by_queue', '📈 Kibana: Sidekiq execution time p95 percentile latency aggregated (split by queue)', 95),
      ])
    ),
  ], startRow=201, rowHeight=5)
  +
  layout.rowGrid('Inflight Jobs - jobs currently running', [
    inflightJobsTimeseries(
      title='Sidekiq Inflight Jobs for $shard shard',
      aggregator='shard'
    ),
    inflightJobsTimeseries(
      title='Sidekiq Inflight Jobs per Queue, $shard shard',
      aggregator='queue'
    ),
    inflightJobsTimeseries(
      title='Sidekiq Inflight Jobs per Worker, $shard shard',
      aggregator='worker'
    )
    .addDataLink(workerDetailDataLink),
  ], startRow=301)
  +
  layout.rowGrid(
    'Total Execution Time - total time consumed processing jobs',
    [
      panel.timeSeries(
        title='Sidekiq Total Execution Time for $shard Shard',
        description='The sum of job execution times',
        query=|||
          sum(rate(sidekiq_jobs_completion_seconds_sum{environment="$environment", shard=~"$shard"}[$__interval])) by (shard)
        |||,
        legendFormat='{{ shard }}',
        interval='1m',
        format='short',
        intervalFactor=1,
        legend_show=true,
        yAxisLabel='Job time completed per second',
      ),
    ],
    startRow=501,
    collapse=true,
  )
  +
  layout.rowGrid(
    'Throughput - rate at which jobs complete',
    [
      panel.timeSeries(
        title='Sidekiq Aggregated Throughput for $shard Shard',
        description='The total number of jobs being completed',
        query=|||
          sum(%(executionOpsRate)s{environment="$environment", shard=~"$shard"}) by (shard)
        ||| % {
          executionOpsRate: recordingRuleRegistry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '5m'),
        },
        legendFormat='{{ shard }}',
        interval='1m',
        intervalFactor=1,
        legend_show=true,
        yAxisLabel='Jobs Completed per Second',
      ),
      panel.timeSeries(
        title='Sidekiq Throughput per Queue for $shard Shard',
        description='The total number of jobs being completed per queue for shard',
        query=|||
          sum(%(executionOpsRate)s{environment="$environment", shard=~"$shard"}) by (queue)
        ||| % {
          executionOpsRate: recordingRuleRegistry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '5m'),
        },
        legendFormat='{{ queue }}',
        interval='1m',
        intervalFactor=1,
        linewidth=1,
        legend_show=true,
        yAxisLabel='Jobs Completed per Second',
      ),
      panel.timeSeries(
        title='Sidekiq Throughput per Worker for $shard Shard',
        description='The total number of jobs being completed per worker for shard',
        query=|||
          application_sli_aggregation:sidekiq_execution:ops:rate_5m{environment="$environment"}
          and on (worker)
          (
            sum by (worker) (
              %(executionOpsRate)s{env="gprd",shard=~"$shard"} > 0
            )
          )
        ||| % {
          executionOpsRate: recordingRuleRegistry.recordingRuleNameFor('gitlab_sli_sidekiq_execution_total', '5m'),
        },
        legendFormat='{{ worker }}',
        interval='1m',
        intervalFactor=1,
        linewidth=1,
        legend_show=true,
        yAxisLabel='Jobs Completed per Second',
      )
      .addDataLink(workerDetailDataLink),
    ],
    startRow=601,
  )
  +
  layout.rowGrid(
    'Utilization - saturation of workers in this fleet',
    [
      panel.percentageTimeSeries(
        'Shard Utilization',
        description='How heavily utilized is this shard? Ideally this should be around 33% plus minus 10%. If outside this range for long periods, consider scaling fleet appropriately.',
        query=|||
          gitlab_component_saturation:ratio_avg_1h{component="sidekiq_shard_workers", environment="$environment", shard="$shard"}
        |||,
        legendFormat='{{ shard }} utilization (per hour)',
        yAxisLabel='Percent',
        interval='5m',
        intervalFactor=1,
        linewidth=2,
        max=1,
        thresholdSteps=[
          threshold.optimalLevel(optimalUtilization - optimalMargin),
          threshold.optimalLevel(optimalUtilization + optimalMargin),
          threshold.warningLevel(optimalUtilization + optimalMargin),
        ]
      )
      .addTarget(
        target.prometheus(
          expr=|||
            avg_over_time(gitlab_component_saturation:ratio{component="sidekiq_shard_workers", environment="$environment", shard="$shard"}[10m])
          |||,
          legendFormat='{{ shard }} utilization (per 10m)'
        )
      )
      .addTarget(
        target.prometheus(
          expr=|||
            gitlab_component_saturation:ratio{component="sidekiq_shard_workers", environment="$environment", shard="$shard"}
          |||,
          legendFormat='{{ shard }} utilization (instant)'
        )
      ),
    ],
    startRow=701
  )
)
.addPanel(
  row.new(title='Rails Metrics', collapse=true)
  .addPanels(railsCommon.railsPanels(serviceType='sidekiq', serviceStage='$stage', startRow=1)),
  gridPos={
    x: 0,
    y: 3000,
    w: 24,
    h: 1,
  }
)
.addPanel(nodeMetrics.nodeMetricsDetailRow(selector), gridPos={ x: 0, y: 4000 })
.addPanel(
  saturationDetail.saturationDetailPanels(
    selectorHash,
    components=[
      'cpu',
      'disk_space',
      'memory',
      'open_fds',
      'sidekiq_shard_workers',
      'single_node_cpu',
      'puma_workers',
    ],
  ),
  gridPos={ x: 0, y: 5000, w: 24, h: 1 }
)
+ {
  links+:
    platformLinks.triage +
    platformLinks.services +
    [
      platformLinks.dynamicLinks('Sidekiq Detail', 'type:sidekiq'),
      link.dashboards(
        'ELK $shard shard logs',
        '',
        type='link',
        targetBlank=true,
        url=elasticsearchLinks.buildElasticDiscoverSearchQueryURL(
          'sidekiq', [
            matching.matchFilter('json.shard', '$shard'),
            matching.matchFilter('json.stage.keyword', '$stage'),
          ]
        ),
      ),
      link.dashboards(
        'ELK $shard shard ops/sec visualization',
        '',
        type='link',
        targetBlank=true,
        url=elasticsearchLinks.buildElasticLineCountVizURL(
          'sidekiq', [
            matching.matchFilter('json.shard', '$shard'),
            matching.matchFilter('json.stage.keyword', '$stage'),
          ]
        ),
      ),
      link.dashboards(
        'ELK $shard shard latency visualization',
        '',
        type='link',
        targetBlank=true,
        url=elasticsearchLinks.buildElasticLinePercentileVizURL(
          'sidekiq',
          [
            matching.matchFilter('json.shard', '$shard'),
            matching.matchFilter('json.stage.keyword', '$stage'),
          ],
          field='json.duration_s'
        ),
      ),
    ],
}
