# HostedRunnersServiceRunnerManagerDownSingleShard

This alert indicates that the GitLab Runner Manager is down or unavailable, which may cause pipeline jobs to fail or stay in pending state for longer time. There are three primary causes for this alert:

## Steps to Troubleshoot

1. **Check if the Customer Deleted the Runner**: The customer might have intentionally or unintentionally deleted the runner from the admin side. To confirm:
   1. Access the GitLab Rails console.
   2. Run the following command (replace $RUNNER_ID with the actual runner ID from hosted runner dashboard):

      ```ruby
      Ci::RunnerManager.where(runner_id: $RUNNER_ID)
      ```

   3. If the command returns `null`, it means the customer has deleted the runner. In this case:
      - **Action**: Communicate with the customer to confirm the reason for deletion.
      - **Fix**: The best option is to deprovision the runner and create a new one via the Switchboard UI, which will also generate a new token.

2. **The EC2 node hosting the Runner Manager is down or absent**: This is more likely be related to the tenant maintenance window, where a new VM for the Runner Manager is being provisioned. If the provisioning takes more than 5 minutes, the alert will be triggered. If the issue isn't related to the maintenance window simply running another provision job will create new runner manager.

3. **The Runner Manager encountered issues**: Check Logs in Tenant's OpenSearch dashboard. Filter the logs using the following Fluentd tag and Analyze the logs for any errors or issues to determine the root cause.

   ```ruby
   fluentd_tag: cloudwatch.${RUNNER_NAME}-fleeting-logs
   ```

## Using Grafana Explore

Use the [Explore](https://grafana.com/docs/grafana/latest/visualizations/explore/get-started-with-explore/#access-explore) function on the customer's Grafana instance to see the specific data which has caused this alert. These queries might help get you started:

```
# Rate of API requests operations per second over the last 5 minutes for a specific shard
gitlab_component_shard_ops:rate_5m{component="api_requests",type="hosted-runners",shard="<shard>"}

# Per-second rate of API request statuses over the last 5 minutes for a specific shard
rate(gitlab_runner_api_request_statuses_total{job="hosted-runners-prometheus-agent",shard="<shard>"}[5m])
```
