local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local templates = import 'grafana/templates.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';

basic.dashboard(
  'Containers Waiting',
  tags=['alert-target', 'kube'],
)
.addTemplate(templates.type)
.addTemplate(templates.stage)
.addTemplate(templates.gkeCluster)
.addPanels(layout.columnGrid([
  [
    panel.timeSeries(
      title='Containers Waiting',
      query=|||
        sum by (reason) (
          kube_pod_container_status_waiting_reason:labeled{
            env="$environment",
            stage="$stage",
            type="$type",
            cluster="$cluster"
          }
        )
      |||,
      legendFormat='{{reason}}',
      linewidth=2,
      stack=true,
      stableId='containers-waiting',
    )
    .addTarget(
      target.prometheus(
        |||
          kube_deployment_spec_strategy_rollingupdate_max_surge:labeled{
            env="$environment",
            stage="$stage",
            type="$type",
            cluster="$cluster"
          }
        |||,
        legendFormat='Max Surge'
      )
    )
    .addTarget(
      target.prometheus(
        |||
          kube_deployment_spec_strategy_rollingupdate_max_surge:labeled{
            env="$environment",
            stage="$stage",
            type="$type",
            cluster="$cluster"
          } * 0.5
        |||,
        legendFormat='50% Alerting Threshold for Max Surge'
      )
    )
    .addSeriesOverride({
      alias: 'Max Surge',
      color: '#FF9830',
      fill: 1,
      stack: false,
    })
    .addSeriesOverride({
      alias: '50% Alerting Threshold for Max Surge',
      color: '#FF9830',
      fill: 2,
      dashes: true,
      dashLength: 2,
      spaceLength: 1,
      stack: false,
    })
    ,
    grafana.text.new(
      title='Container Waiting Reasons',
      mode='markdown',
      content=|||
        ### Container Waiting Reasons

        This shows reasons why containers are waiting to start. At a maximum, the `Max Surge` value
        will limit the maximum number of containers that are waiting to start. The `KubeContainersWaitingInError`
        when the number of containers that are waiting to start for reasons other than `ContainerCreating` is
        at 50% of the `Max Surge` value.

        See https://runbooks.gitlab.com/kube/kubernetes/#alerts for more details.
      |||
    ),
  ],
], columnWidths=[18, 6], rowHeight=15))
.trailer()
