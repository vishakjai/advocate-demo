local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local runnersService = (import 'servicemetrics/metrics-catalog.libsonnet').getService('ci-runners');

local type = template.new(
  'type',
  '$PROMETHEUS_DS',
  query=|||
    label_values(gitlab_runner_version_info{job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner", environment="$environment"}, type)
  |||,
  current=runnersService.type,
  refresh='load',
  sort=1,
);

local shard = template.new(
  'shard',
  '$PROMETHEUS_DS',
  query=|||
    label_values(gitlab_runner_version_info{environment=~"$environment",stage=~"$stage",type=~"$type",shard!="default"}, shard)
  |||,
  current=null,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
);

local runnerJobFailureReason = template.new(
  'runner_job_failure_reason',
  '$PROMETHEUS_DS',
  query=|||
    label_values(gitlab_runner_failed_jobs_total{environment=~"$environment",stage=~"$stage"}, failure_reason)
  |||,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
);

local projectJobsRunning = template.new(
  'project_jobs_running',
  '$PROMETHEUS_DS',
  query=|||
    label_values(gitlab_runner_job_queue_duration_seconds_sum{environment=~"$environment",stage=~"$stage"}, project_jobs_running)
  |||,
  current='All',
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true
);

local gcpExporter = template.new(
  'gcp_exporter',
  '$PROMETHEUS_DS',
  query=|||
    label_values(gcp_exporter_region_quota_limit{environment=~"$environment",stage=~"$stage"}, instance)
  |||,
  refresh='load',
  sort=true,
  multi=false,
  includeAll=false
);

local gcpProject = template.new(
  'gcp_project',
  '$PROMETHEUS_DS',
  query=|||
    label_values(gcp_exporter_region_quota_limit{environment=~"$environment",stage=~"$stage"}, project)
  |||,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
);

local gcpRegion = template.new(
  'gcp_region',
  '$PROMETHEUS_DS',
  query=|||
    label_values(gcp_exporter_region_quota_usage{environment=~"$environment",stage=~"$stage"}, region)
  |||,
  refresh='load',
  sort=true,
  multi=true,
  includeAll=true,
);

local dbInstance = template.new(
  'db_instance',
  '$PROMETHEUS_DS',
  query=|||
    query_result(pg_replication_is_replica{environment=~"$environment",stage=~"$stage",type="patroni-ci"} == 0)
  |||,
  regex='/.*fqdn="(.*?)".*/',
  refresh='load',
  hide='all',
  sort=true,
  multi=false,
  includeAll=false,
);

local dbInstances = template.new(
  'db_instances',
  '$PROMETHEUS_DS',
  query=|||
    label_values(pg_slow_queries{environment=~"$environment",stage=~"$stage",type="patroni-ci"},fqdn)
  |||,
  refresh='load',
  hide='all',
  sort=true,
  multi=true,
  includeAll=true,
);
local dbDatabase = template.new(
  'db_database',
  '$PROMETHEUS_DS',
  query=|||
    label_values(pg_stat_database_tup_deleted{environment=~"$environment",stage=~"$stage",fqdn="$db_instance"}, datname)
  |||,
  regex='/gitlabhq_.*/',
  refresh='load',
  hide='all',
  sort=true,
  multi=false,
  includeAll=false,
);

local dbTopDeadTuples = template.new(
  'db_top_dead_tup',
  '$PROMETHEUS_DS',
  query=|||
    query_result(topk(20, max_over_time(pg_stat_user_tables_n_dead_tup{environment=~"$environment",stage=~"$stage",fqdn="$db_instance",datname="$db_database"}[${__range_s}s])))
  |||,
  regex='/.*relname="(.*?)".*/',
  refresh='load',
  hide='all',
  sort=true,
  multi=true,
  includeAll=true,
);

local selectorHash = {
  type: '$type',
  tier: runnersService.tier,
  environment: '$environment',
  stage: '$stage',
};

{
  type:: type,
  shard:: shard,
  runnerJobFailureReason:: runnerJobFailureReason,
  projectJobsRunning:: projectJobsRunning,
  gcpExporter:: gcpExporter,
  gcpProject:: gcpProject,
  gcpRegion:: gcpRegion,
  dbInstance:: dbInstance,
  dbInstances:: dbInstances,
  dbDatabase:: dbDatabase,
  dbTopDeadTuples:: dbTopDeadTuples,

  selectorHash:: selectorHash,
}
