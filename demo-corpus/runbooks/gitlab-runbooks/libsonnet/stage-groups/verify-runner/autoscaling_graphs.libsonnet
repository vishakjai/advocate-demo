local panels = import './panels.libsonnet';
local thresholds = import 'gitlab-dashboards/thresholds.libsonnet';
local override = import 'grafana/time-series/override.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local threshold = import 'grafana/time-series/threshold.libsonnet';

local vmStates() =
  panel.timeSeries(
    'Autoscaled VMs states',
    legendFormat='{{shard}}: {{state}}',
    format='short',
    query=|||
      sum by(shard, state) (
        gitlab_runner_autoscaling_machine_states{environment=~"$environment", stage=~"$stage", executor="docker+machine", shard=~"${shard:pipe}"}
      )
    |||,
  );

local vmOperationsRate() =
  panel.timeSeries(
    'Autoscaled VM operations rate',
    legendFormat='{{shard}}: {{action}}',
    format='ops',
    fill=10,
    stack=true,
    query=|||
      sum by (shard, action) (
        increase(gitlab_runner_autoscaling_actions_total{environment=~"$environment", stage=~"$stage", executor="docker+machine", shard=~"${shard:pipe}"}[$__rate_interval])
      )
    |||,
  );

local vmCreationTiming() =
  panels.heatmap(
    'Autoscaled VMs creation timing',
    |||
      sum by (le) (
        increase(gitlab_runner_autoscaling_machine_creation_duration_seconds_bucket{environment=~"$environment", stage=~"$stage", executor="docker+machine",shard=~"${shard:pipe}"}[$__rate_interval])
      )
    |||,
    color_mode='spectrum',
    color_colorScheme='Greens',
    legend_show=true,
    intervalFactor=2,
  );

local idleEfficiency() =
  panel.timeSeries(
    'Idle efficiency',
    legendFormat='{{shard}}',
    format='percentunit',
    query=|||
      1 - (
        sum by(shard) (
          gitlab_runner_autoscaling_machine_states{environment=~"$environment", stage=~"$stage", executor="docker+machine", shard=~"${shard:pipe}", state=~"idle|acquired"}
        )
        /
        sum by(shard) (
          gitlab_runner_autoscaling_machine_states{environment=~"$environment", stage=~"$stage", executor="docker+machine", shard=~"${shard:pipe}"}
        )
      )
    |||,
    description=|||
      Shows what percentages of instances are in the idle or acquired state. There is no golden rule here and the metric
      should be analyzed together with raw numbers showing the different instance states, but in a very generlized view:
      the higher number the better, more than 50% is what we aim to if there is a constant number of jobs in the
      incoming queue for a shard. For shards that have times with no jobs in the queue, having the efficiency dropped
      below 50% is something normal, but in that case we aim to have a small raw number of idle instances.
    |||,
    thresholdSteps=[
      threshold.warningLevel(0.5),
      threshold.optimalLevel(0.5),
    ],
  );

local gcpRegionQuotas =
  panel.timeSeries(
    'GCP region quotas',
    legendFormat='{{project}}: {{region}}: {{quota}}',
    format='percentunit',
    query=|||
      sum by(project, region, quota) (
        (
          gcp_exporter_region_quota_usage{environment=~"$environment", stage=~"$stage", instance=~"$gcp_exporter",project=~"${gcp_project:pipe}",region=~"${gcp_region:pipe}"}
          /
          gcp_exporter_region_quota_limit{environment=~"$environment", stage=~"$stage", instance=~"$gcp_exporter",project=~"${gcp_project:pipe}",region=~"${gcp_region:pipe}"}
        ) > 0
      )
    |||,
  ).addTarget(
    target.prometheus(
      expr='0.85',
      legendFormat='Soft SLO',
    )
  ).addTarget(
    target.prometheus(
      expr='0.9',
      legendFormat='Hard SLO',
    )
  ).addSeriesOverride(
    override.hardSlo
  ).addSeriesOverride(
    override.softSlo
  );

local gcpInstances =
  panel.timeSeries(
    'GCP instances',
    legendFormat='{{runner_group}} - {{zone}} - {{machine_type_short}}',
    format='short',
    query=|||
      sum by (zone, machine_type_short, runner_group) (
        label_replace(
          label_replace(
            gcp_exporter_instances_count{environment=~"$environment", stage=~"$stage", instance=~"$gcp_exporter",project="${gcp_project:pipe}",zone=~"(${gcp_region:pipe}).*"},
            "machine_type_short",
            "$1",
            "machine_type",
            ".*/([^/]+)$"
          ),
          "runner_group",
          "$2",
          "tags",
          "(.*,)?(srm|prm|gsrm)(,.*)?"
        )
      )
    |||,
  );

{
  vmStates:: vmStates,
  vmOperationsRate:: vmOperationsRate,
  vmCreationTiming:: vmCreationTiming,
  idleEfficiency:: idleEfficiency,
  gcpRegionQuotas:: gcpRegionQuotas,
  gcpInstances:: gcpInstances,
}
