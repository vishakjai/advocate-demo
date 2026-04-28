local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local templates = import 'grafana/templates.libsonnet';

local template = grafana.template;

{
  // stackSelector: groups runner managers by Stack.
  // Shard label values look like "green-abc123" where "green" is the
  // deployment color and "abc123" is the Stack name. The regex captures
  // only the Stack suffix so the dropdown shows "abc123" rather than
  // individual shard values.
  // Queries use shard=~".+-(${stack:pipe})" to match all shards in a Stack.
  stackSelector::
    template.new(
      'stack',
      '$PROMETHEUS_DS',
      label='Stack',
      query=|||
        label_values(gitlab_runner_version_info,shard)
      |||,
      regex='/[^-]+-(.+)/',
      current='All',
      refresh='time',
      sort=true,
      multi=true,
      includeAll=true
    ),

  // shardSelector: cascades from $stack, shows individual shard values
  // (e.g. "green-abc123") for the selected Stack(s).
  // Use this to drill down to a specific deployment color within a Stack.
  shardSelector::
    template.new(
      'shard',
      '$PROMETHEUS_DS',
      label='Shard',
      query=|||
        label_values(gitlab_runner_version_info{shard=~".+-(${stack:pipe})"},shard)
      |||,
      current='All',
      refresh='time',
      sort=true,
      multi=true,
      includeAll=true
    ),

  runnerID::
    template.new(
      'runnerID',
      '$PROMETHEUS_DS',
      query=|||
        label_values(gitlab_runner_version_info,runner_id)
      |||,
      current='All',
      refresh='time',
      sort=true,
      multi=false,
      includeAll=false
    ),

  fluentdPlugin::
    template.new(
      'plugin',
      '$PROMETHEUS_DS',
      query=|||
        label_values(fluentd_output_status_flush_time_count,plugin)
      |||,
      current='All',
      refresh='time',
      sort=true,
      multi=false,
      includeAll=false
    ),
}
