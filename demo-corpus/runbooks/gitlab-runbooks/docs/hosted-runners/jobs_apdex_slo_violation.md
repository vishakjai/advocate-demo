# HostedRunnersServiceCiRunnerJobsApdexSLOViolationSingleShard

This alert triggers when the Apdex score for GitLab Hosted Runners drops below the predefined threshold, signaling potential performance degradation. The Apdex violation occurs when a runner fails to pick up jobs within the expected time, indicating a decline in user experience. Apdex for runners is primarily calculated from job queue times.

**Possible Causes**

• **Traffic spikes**: Unexpected traffic can lead to resource exhaustion (e.g., CPU, memory).
• **Database issues**: Slow queries, connection problems, or database performance degradation.
• **Recent deployments**: New code releases could introduce bugs or performance problems.
• **Network or server problems**: Performance impacted by underlying infrastructure issues.

**General Troubleshooting Steps**

1. **Identify slow requests via SLI metrics**
    • Review Service Level Indicators (SLIs) to identify metrics with elevated request times.
    • Examine logs and metrics around these slow requests to understand the performance degradation.
    • Check API request for `500` errors:
        ```
        sum(increase(gitlab_runner_api_request_statuses_total{status=~"5.."}[5m])) by (status, endpoint)
        ```
2. **Job Queue**
    • Pending job queue duration histogram percentiles may also point to a degradation. Note this metric is only calculated when jobs are actually being picked up, so in a total hosted runner outage it will not appear like there is any queue until the runners start processing jobs again, at which point there will suddenly be a large queue.

    Read more in [pending_queue_duration](./pending_queue_duration.md)

3. **Review logs and metrics**
    • **Logs**: Search for errors, timeouts, or slow queries related to the affected services.
    • **Metrics**: Use Prometheus/Grafana to observe CPU, memory, and network utilization metrics for anomalies.
4. **Investigate recent deployments**
    • Identify if any recent code, configuration changes, or infrastructure updates have occurred.
    • Rollback or redeploy services if the issue is related to a faulty deployment.
5. **Examine traffic patterns and spikes**
    • Analyze traffic logs and monitoring dashboards for unusual spikes.
    • Assess whether traffic surges correlate with the Apdex violations and resource exhaustion.

## Using Grafana Explore

Use the [Explore](https://grafana.com/docs/grafana/latest/visualizations/explore/get-started-with-explore/#access-explore) function on the customer's Grafana instance to see the specific data which has caused this alert. These queries might help get you started:

```
# Total count of API requests with 5xx status codes over the last 5 minutes, grouped by status and endpoint
sum(increase(gitlab_runner_api_request_statuses_total{status=~"5.."}[5m])) by (status, endpoint)
```
