local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local selectors = import 'promql/selectors.libsonnet';
local template = grafana.template;
local commonAnnotations = import 'grafana/common_annotations.libsonnet';
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

// This dashboard currently shows both the `{{region}}` and `{{location}}` label.
// We do this because in Thanos the `region` label on metrics gets overridden by
// the external_label advertised by Prometheus.
// This does not happen in Mimir, so when the migration is complete we can remove
// references to the location label
// https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/3398

local formatConfig = {
  selector: selectors.serializeHash({ job: 'runway-exporter', env: '$environment', type: '$type', location: { re: '$region' } }),
};

basic.dashboard(
  'Runway Job Metrics',
  tags=['runway', 'type:runway'],
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=mimirHelper.mimirDatasource('runway')
)
.addTemplate(template.new(
  'type',
  '$PROMETHEUS_DS',
  'label_values(stackdriver_cloud_run_job_run_googleapis_com_job_running_task_attempts{job="runway-exporter", env="$environment"}, job_name)',
  label='job',
  refresh='load',
  sort=1,
))
.addTemplate(template.new(
  'region',
  '$PROMETHEUS_DS',
  'label_values(stackdriver_cloud_run_job_run_googleapis_com_job_running_task_attempts{job="runway-exporter", env="$environment", type="$type"}, location)',
  refresh='load',
  sort=1,
  includeAll=true,
  allValues='.*',
))
.addAnnotation(commonAnnotations.deploymentsForRunway('${type}'))
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Completed execution',
        description='Number of completed executions',
        yAxisLabel='Completed execution count',
        query=|||
          sum by (type, result) (
            clamp_min(stackdriver_cloud_run_job_run_googleapis_com_job_completed_execution_count{%(selector)s}, 1)
          )
        ||| % formatConfig,
        intervalFactor=2,
        drawStyle='bars',
      ),
      panel.timeSeries(
        title='Completed task attempts',
        description='Number of task attempts including retries',
        yAxisLabel='Completed task attempts count',
        query=|||
          sum by (type, result) (
            clamp_min(
              stackdriver_cloud_run_job_run_googleapis_com_job_completed_task_attempt_count{%(selector)s}
            , 1)
          )
        ||| % formatConfig,
        intervalFactor=2,
        drawStyle='bars',
      ),
      panel.timeSeries(
        title='Running executions',
        description='Number of running execution including retries',
        yAxisLabel='Running execution count',
        query=|||
          count by (type) (
            stackdriver_cloud_run_job_run_googleapis_com_job_running_executions{%(selector)s}
          )
        ||| % formatConfig,
        intervalFactor=2,
        drawStyle='bars',
      ),
      panel.timeSeries(
        title='Running task attempts',
        description='Number of running task including retries',
        yAxisLabel='Running task attempts count',
        query=|||
          count by (type, attempt) (
            stackdriver_cloud_run_job_run_googleapis_com_job_running_task_attempts{%(selector)s}
          )
        ||| % formatConfig,
        intervalFactor=2,
        drawStyle='bars',
      ),
      panel.timeSeries(
        title='Runway Service Billable Container Instance Time',
        description='Billable time aggregated from all container instances.',
        yAxisLabel='Seconds per Second',
        query=|||
          sum by (service_name) (
            stackdriver_cloud_run_job_run_googleapis_com_container_billable_instance_time{%(selector)s}
          ) / 60
        ||| % formatConfig,
        legendFormat='{{service_name}}',
        intervalFactor=2,
        drawStyle='bars',
      ),
      panel.percentageTimeSeries(
        title='Runway Service CPU Utilization',
        description='Container CPU utilization distribution across all container instances.',
        query=|||
          histogram_quantile(
            0.99,
            sum by (job_name, region, location, le) (
              max_over_time(stackdriver_cloud_run_job_run_googleapis_com_container_cpu_utilizations_bucket{%(selector)s}[$__interval])
            )
          )
        ||| % formatConfig,
        legendFormat='p99 {{job_name}} {{region}} {{location}}',
        interval='2m',
        intervalFactor=3,
        min=0,
        max=1,
      ),
      panel.percentageTimeSeries(
        title='Runway Service Memory Utilization',
        description='Container memory utilization distribution across all container instances.',
        query=|||
          histogram_quantile(
            0.99,
            sum by (job_name, region, location, le) (
              max_over_time(stackdriver_cloud_run_job_run_googleapis_com_container_memory_utilizations_bucket{%(selector)s}[$__interval])
            )
          )
        ||| % formatConfig,
        legendFormat='p99 {{job_name}} {{region}} {{location}}',
        interval='2m',
        intervalFactor=3,
        min=0,
        max=1,
      ),
      panel.networkTrafficGraph(
        title='Sent bytes by Kind',
        description='Outgoing socket and HTTP response traffic, in bytes.',
        sendQuery=|||
          sum by(kind) (
            stackdriver_cloud_run_job_run_googleapis_com_container_network_sent_bytes_count{%(selector)s}
          ) / 60
        ||| % formatConfig,
        legendFormat='{{kind}}',
      ),
      panel.networkTrafficGraph(
        title='Received bytes by Kind',
        description='Incoming socket and HTTP response traffic, in bytes.',
        receiveQuery=|||
          sum by(kind) (
            stackdriver_cloud_run_job_run_googleapis_com_container_network_received_bytes_count{%(selector)s}
          ) * -1 / 60
        ||| % formatConfig,
        legendFormat='{{kind}}',
      ),
    ],
  )
)
