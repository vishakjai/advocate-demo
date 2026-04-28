local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

local runner_saturation(shard, gduid='', slot_soft=0.90, slot_hard=0.95) =
  resourceSaturationPoint({
    title: '%s Runner utilization' % shard,
    severity: 's4',
    horizontallyScalable: true,
    appliesTo: ['ci-runners'],
    description: |||
      %s runner utilization per instance.

      Each runner manager has a maximum number of runners that it can coordinate at any single moment.

      When this metric is saturated, new CI jobs will queue. When this occurs we should consider adding more runner managers,
      or scaling the runner managers vertically and increasing their maximum runner capacity.
    ||| % shard,
    grafana_dashboard_uid: if gduid != '' then gduid else 'sat_%s_runners' % std.strReplace(shard, '-', '_'),
    resourceLabels: ['instance'],
    staticLabels: {
      type: 'ci-runners',
      tier: 'runners',
      stage: 'main',
    },
    query: |||
      sum without(executor_stage, exported_stage, state) (
        max_over_time(gitlab_runner_jobs{job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner",shard="%(shard)s"}[%(rangeInterval)s])
      )
      /
      gitlab_runner_limit{job=~"runners-manager|scrapeConfig/monitoring/prometheus-agent-runner",shard="%(shard)s"} > 0
    ||| % {
      shard: shard,
      // hack around the fact that `query` is passed through formatting again internally in resourceSaturationPoint()
      rangeInterval: '%(rangeInterval)s',
    },
    slos: {
      soft: slot_soft,
      hard: slot_hard,
    },
  });

{
  // shared-gitlab-org and private runners are also part of our SaaS fleet,
  // dedicated to our internal usage though (and in case of shared-gitlab-org
  // also shared with the community contributors)
  private_runners: runner_saturation('private', slot_soft=0.85),
  shared_runners_gitlab: runner_saturation('shared-gitlab-org', gduid='sat_shared_runners_gitlab'),

  // Customer facing SaaS runner fleet
  saas_linux_large_amd64_runners: runner_saturation('saas-linux-large-amd64', gduid='sat_r_saas_l_l_amd64'),
  saas_linux_medium_amd64_runners: runner_saturation('saas-linux-medium-amd64', gduid='sat_r_saas_l_m_amd64'),
  saas_linux_medium_amd64_gpu_standard_runners: runner_saturation('saas-linux-medium-amd64-gpu-standard', gduid='sat_r_saas_l_m_amd64_g_s'),
  saas_linux_small_amd64_runners: runner_saturation('saas-linux-small-amd64', gduid='sat_r_saas_l_s_amd64'),
  saas_macos_medium_m1_runners: runner_saturation('saas-macos-medium-m1', gduid='sat_r_saas_m_m_m1'),

  // SaaS Windows runners are still using the old naming pattern of the shard.
  windows_shared_runners: runner_saturation('windows-shared'),
}
