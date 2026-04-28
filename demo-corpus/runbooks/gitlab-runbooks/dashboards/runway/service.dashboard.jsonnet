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
  'Runway Service Metrics',
  tags=['runway', 'type:runway'],
  includeStandardEnvironmentAnnotations=false,
  defaultDatasource=mimirHelper.mimirDatasource('runway')
)
.addTemplate(template.new(
  'type',
  '$PROMETHEUS_DS',
  'label_values(stackdriver_cloud_run_revision_run_googleapis_com_container_instance_count{job="runway-exporter", env="$environment"}, service_name)',
  label='service',
  refresh='load',
  sort=1,
))
.addTemplate(template.new(
  'region',
  '$PROMETHEUS_DS',
  'label_values(stackdriver_cloud_run_revision_run_googleapis_com_container_instance_count{job="runway-exporter", env="$environment", type="$type"}, location)',
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
        title='Request count by Status',
        description='Number of requests reaching the service, grouped by HTTP response status',
        yAxisLabel='Requests per Second',
        query=|||
          sum by (response_code_class) (
            stackdriver_cloud_run_revision_run_googleapis_com_request_count{%(selector)s}
          ) / 60
        ||| % formatConfig,
        legendFormat='HTTP status {{response_code_class}}',
        intervalFactor=2,
      ),
      panel.timeSeries(
        title='Request count by Region',
        description='Number of requests reaching the service, grouped by region',
        yAxisLabel='Requests per Second',
        query=|||
          sum by (region, location) (
            stackdriver_cloud_run_revision_run_googleapis_com_request_count{%(selector)s}
          ) / 60
        ||| % formatConfig,
        legendFormat='Region {{location}}',
        intervalFactor=2,
      ),
      panel.percentageTimeSeries(
        title='Error ratio',
        description='Ratio of errors (HTTP status 5xx) to total requests',
        yAxisLabel='Error ratio',
        query=|||
          sum (
            stackdriver_cloud_run_revision_run_googleapis_com_request_count{response_code_class="5xx",%(selector)s}
            OR on() vector(0)
          )
          /
          sum (
            stackdriver_cloud_run_revision_run_googleapis_com_request_count{%(selector)s}
          )
        ||| % formatConfig,
        legendFormat='Overall error ratio',
        intervalFactor=2,
        min=0,
      ),
      panel.percentageTimeSeries(
        title='Error ratio by Revision',
        description='Ratio of errors (HTTP status 5xx) to total requests, grouped by revision',
        yAxisLabel='Error ratio',
        query=|||
          sum by(revision_name) (
            stackdriver_cloud_run_revision_run_googleapis_com_request_count{response_code_class="5xx",%(selector)s}
            OR on(revision_name) vector(0)
          )
          / on(revision_name)
          sum by(revision_name) (
            stackdriver_cloud_run_revision_run_googleapis_com_request_count{%(selector)s}
          )
        ||| % formatConfig,
        legendFormat='Revision {{revision_name}}',
        intervalFactor=2,
        min=0,
      ),
      panel.latencyTimeSeries(
        title='Runway Service Request Latency',
        description='Distribution of request times reaching the service, in milliseconds.',
        yAxisLabel='Duration',
        query=|||
          histogram_quantile(
            0.99,
            sum by (revision_name, region, location, le) (
              rate(stackdriver_cloud_run_revision_run_googleapis_com_request_latencies_bucket{%(selector)s}[$__interval])
            )
          )
        ||| % formatConfig,
        format='ms',
        legendFormat='p99 {{revision_name}} {{region}} {{location}}',
        intervalFactor=2,
      ),
      panel.timeSeries(
        title='Runway Service Container Instance Count',
        description='Number of container instances that exist for the service.',
        yAxisLabel='Container Instances per Second',
        query=|||
          sum by (revision_name, region, location) (
            max_over_time(
              stackdriver_cloud_run_revision_run_googleapis_com_container_instance_count{%(selector)s}[${__interval}]
            )
          )
        ||| % formatConfig,
        legendFormat='{{revision_name}} {{region}} {{location}}',
        intervalFactor=2,
      ),
      panel.timeSeries(
        title='Runway Service Billable Container Instance Time',
        description='Billable time aggregated from all container instances.',
        yAxisLabel='Seconds per Second',
        query=|||
          sum by (service_name) (
            stackdriver_cloud_run_revision_run_googleapis_com_container_billable_instance_time{%(selector)s}
          ) / 60
        ||| % formatConfig,
        legendFormat='{{service_name}}',
        intervalFactor=2,
      ),
      panel.percentageTimeSeries(
        title='Runway Service CPU Utilization',
        description='Container CPU utilization distribution across all container instances.',
        query=|||
          histogram_quantile(
            0.99,
            sum by (revision_name, region, location, le) (
              max_over_time(stackdriver_cloud_run_revision_run_googleapis_com_container_cpu_utilizations_bucket{%(selector)s}[$__interval])
            )
          )
        ||| % formatConfig,
        legendFormat='p99 {{revision_name}} {{region}} {{location}}',
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
            sum by (revision_name, region, location, le) (
              max_over_time(stackdriver_cloud_run_revision_run_googleapis_com_container_memory_utilizations_bucket{%(selector)s}[$__interval])
            )
          )
        ||| % formatConfig,
        legendFormat='p99 {{revision_name}} {{region}} {{location}}',
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
            stackdriver_cloud_run_revision_run_googleapis_com_container_network_sent_bytes_count{%(selector)s}
          ) / 60
        ||| % formatConfig,
        legendFormat='{{kind}}',
      ),
      panel.networkTrafficGraph(
        title='Received bytes by Kind',
        description='Incoming socket and HTTP response traffic, in bytes.',
        receiveQuery=|||
          sum by(kind) (
            stackdriver_cloud_run_revision_run_googleapis_com_container_network_received_bytes_count{%(selector)s}
          ) * -1 / 60
        ||| % formatConfig,
        legendFormat='{{kind}}',
      ),
      panel.percentageTimeSeries(
        title='Runway Service Max Concurrent Requests',
        description='Distribution of the maximum number number of concurrent requests being served by each container instance over a minute.',
        query=|||
          histogram_quantile(
            0.99,
            sum by (revision_name, region, location, le) (
              max_over_time(stackdriver_cloud_run_revision_run_googleapis_com_container_max_request_concurrencies_bucket{%(selector)s}[$__interval])
            )
          ) / 100
        ||| % formatConfig,
        legendFormat='p99 {{revision_name}} {{region}} {{location}}',
        interval='2m',
        intervalFactor=3,
        min=0,
        max=1,
      ),
      panel.latencyTimeSeries(
        title='Runway Service Container p99 Startup Latency',
        description='Distribution of time spent starting a new container instance, in milliseconds.',
        query=|||
          histogram_quantile(
            0.99,
            sum by (le, revision_name, region, location) (
              max_over_time(stackdriver_cloud_run_revision_run_googleapis_com_container_startup_latencies_bucket{%(selector)s}[$__interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{revision_name}} {{region}} {{location}}',
        format='ms',
        intervalFactor=2,
      ),
      panel.timeSeries(
        title='Runway Service Container Healthcheck Requests',
        description='Request rate of healthcheck attempts for the ingress container',
        query=|||
          sum by (revision_name, region, location, probe_type, is_healthy) (
            stackdriver_cloud_run_revision_run_googleapis_com_container_completed_probe_attempt_count{%(selector)s, container_name='ingress'}
          ) / 60
        ||| % formatConfig,
        legendFormat='{{revision_name}} {{region}} {{location}} {{probe_type}} healthy: {{is_healthy}}',
        intervalFactor=2,
      ),
      panel.latencyTimeSeries(
        title='Runway Service Container p99 Healthcheck Latency',
        description='Distribution of time spent probing a container instance, in milliseconds.',
        query=|||
          histogram_quantile(
            0.99,
            sum by (le, revision_name, region, location, probe_type, is_healthy) (
              max_over_time(stackdriver_cloud_run_revision_run_googleapis_com_container_probe_attempt_latencies_bucket{%(selector)s, container_name='ingress'}[$__interval])
            )
          )
        ||| % formatConfig,
        legendFormat='{{revision_name}} {{region}} {{location}} {{probe_type}} healthy: {{is_healthy}}',
        format='ms',
        intervalFactor=2,
      ),
    ],
  )
)
