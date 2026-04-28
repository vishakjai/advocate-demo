# HostedRunnersServicePendingBuildsSaturationSingleShard

## Description

This alert indicates that there is a large number of CI pending builds, signaling potential issues with runner performance or capacity.

## General Troubleshooting Steps

1. **Check Hosted Runner Dashboard**
   - Verify the dashboard to confirm there is a large number of pending CI builds.

2. **Verify Runner Health**
   - Ensure the runner is working correctly and not experiencing a high number of errors.

3. **Check AWS Fleeting Machines**
   - Verify that AWS fleeting machines are being created successfully by checking the AWS dashboard or the logging dashboards.
   - You should see logs like the following, indicating that instances are being created:

     ```text
     gitlab-runner[3066]: increasing instances
     ```

4. **Debugging Fleeting Errors**
   - If you do not see the expected log entries, check the logs for any fleeting-related errors to help identify and resolve the issue.

5. **Check scaleMax Saturation**

   - If there is an increase in the pending job queue, and runner saturation of concurrent is higher than 80%, you may be nearing the concurrent job limit for that runner stack. If so, you can increase the number of concurrent jobs able to be processed at a time by increasing that runner stacks `scaleMax`.

`scaleMax` in a runner model is equivalent to [concurrent](https://docs.gitlab.com/runner/configuration/advanced-configuration/#:~:text=Description-,concurrent,-Limits%20how%20many) and [max_instances](https://docs.gitlab.com/runner/configuration/advanced-configuration/#:~:text=scheduled%20for%20removal.-,max_instances,-The%20maximum%20number) in the runners config.toml.

To increase scaleMax, go into Switchboard, go into that runners model, open the runner model overrides section, increase scaleMax, save and redeploy that runner by running the provision, shutdown and cleanup jobs for that runner. It is important you make this change in the overrides section, not directly in the runner model.

```
{
  "stack": {
    ...
    "scaleMax": 100, # example number, use your best judgement
  }
}
```

Note as of Jan 2026 we have not tested scaleMax above 400 and believe there are potential negative performance implications of a scaleMax above 400 on the kubernetes cluster which contains the registry server. Specifically, nodes OOMKills for memory saturation.

Then you should be able to go back into the metrics in Grafana and see an increased concurrent job limit, a decreased runner saturaton of concurrent and a decrease in the Pending job queue duration histogram percentiles. Note that the active runner while have switched from blue to green or vice versa, so you may need to select a different runner in the dashboard dropdown to see the changes.

6. **Check scaleFactor Saturation**

   - If there is an increase in the pending job queue, but the customer is NOT hitting concurrency limit, and as soon as the runners scale up, the queue drops to near zero - there may be a bottleneck in the scale-up speed/behavior. If so, you can increase the magnitude of scaling by increasing that runner stacks `scaleFactor`.

`scaleFactor` in a runner model is equivalent to [scale_factor](https://docs.gitlab.com/runner/configuration/advanced-configuration/#:~:text=it%20is%20terminated.-,scale_factor,-The%20target%20idle) in the runners config.toml.

To increase scaleFactor, go into Switchboard, go into that runners model, open the runner model overrides section, increase scaleFactor, save and redeploy that runner by running the provision, shutdown and cleanup jobs for that runner. It is important you make this change in the overrides section, not directly in the runner model.

```
{
  "stack": {
    ...
    "scaleFactor": 5, # example number, use your best judgement
  }
}
```

Note that increasing scaleFactor is expensive because it increases the number of idle machines for each machine in use non-linearly.

Then you should be able to go back into the metrics in Grafana and see a decrease in the Pending job queue duration histogram percentiles. Note that the active runner while have switched from blue to green or vice versa, so you may need to select a different runner in the dashboard dropdown to see the changes.

## Using Grafana Explore

Use the [Explore](https://grafana.com/docs/grafana/latest/visualizations/explore/get-started-with-explore/#access-explore) function on the customer's Grafana instance to see the specific data which has caused this alert. These queries might help get you started:

```
# 95th percentile of job queue duration in seconds over the last 5 minutes for a specific shard
histogram_quantile(0.95, sum by (le,shard) (rate(gitlab_runner_job_queue_duration_seconds_bucket{job="hosted-runners-prometheus-agent",shard="<shard>"}[5m])))

# Apdex score for pending builds over the last 1 hour for a specific shard
gitlab_component_shard_apdex:ratio_1h{component="pending_builds",type="hosted-runners",shard="<shard>"}

# Apdex score for pending builds over the last 5 minutes for a specific shard
gitlab_component_shard_apdex:ratio_5m{component="pending_builds",type="hosted-runners",shard="<shard>"}

# Apdex score for pending builds over the last 6 hours for a specific shard
gitlab_component_shard_apdex:ratio_6h{component="pending_builds",type="hosted-runners",shard="<shard>"}

# Apdex score for pending builds over the last 30 minutes for a specific shard
gitlab_component_shard_apdex:ratio_30m{component="pending_builds",type="hosted-runners",shard="<shard>"}

# Saturation ratio showing resource utilization for pending builds
gitlab_component_saturation:ratio{component="pending_builds"}
```
