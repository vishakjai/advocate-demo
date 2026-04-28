local panel = import 'grafana/time-series/panel.libsonnet';

local defaultSelector = 'environment=~"$environment", stage=~"$stage", shard=~"${shard:pipe}"';

local workerFeedRate(selector=defaultSelector) =
  panel.timeSeries(
    'Worker feed rate',
    description='Rate at which worker goroutines call GitLab to request a new job. A drop indicates runners have stopped polling — check connectivity and authentication.',
    legendFormat='{{shard}}',
    format='ops',
    query=|||
      sum by(shard) (
        increase(
          gitlab_runner_worker_feeds_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local workerFeedFailuresRate(selector=defaultSelector) =
  panel.timeSeries(
    'Worker feed failures rate',
    description='Rate of failed poll attempts when workers request jobs from GitLab. Sustained non-zero values indicate a connectivity, token, or GitLab availability problem.',
    legendFormat='{{shard}}',
    format='ops',
    query=|||
      sum by(shard) (
        increase(
          gitlab_runner_worker_feed_failures_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local workerSlots(selector=defaultSelector) =
  panel.timeSeries(
    'Worker slots',
    description='Current number of available worker slots. Each slot can hold one in-flight job; this should roughly track the configured concurrent setting.',
    legendFormat='{{shard}}',
    format='short',
    query=|||
      sum by(shard) (
        gitlab_runner_worker_slots_number{%(selector)s}
      )
    ||| % { selector: selector },
  );

local workerSlotOperationsRate(selector=defaultSelector) =
  panel.timeSeries(
    'Worker slot operations rate',
    description='Rate of worker slot acquire/release operations. High release rates relative to acquire rates can indicate rapid job failures.',
    legendFormat='{{shard}}',
    format='ops',
    query=|||
      sum by(shard) (
        increase(
          gitlab_runner_worker_slot_operations_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local workerProcessingFailuresRate(selector=defaultSelector) =
  panel.timeSeries(
    'Worker processing failures rate',
    description='Rate of job-processing failures broken down by failure_type (e.g. runner_system_failure, script_failure).',
    legendFormat='{{shard}}: {{failure_type}}',
    format='ops',
    query=|||
      sum by(shard, failure_type) (
        increase(
          gitlab_runner_worker_processing_failures_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local workerHealthCheckFailuresRate(selector=defaultSelector) =
  panel.timeSeries(
    'Worker health check failures rate',
    description='Rate of worker health-check failures by runner instance. These indicate a worker goroutine has become unhealthy or unable to communicate with the executor.',
    legendFormat='{{shard}}: {{runner_name}}',
    format='ops',
    query=|||
      sum by(shard, runner_name) (
        increase(
          gitlab_runner_worker_health_check_failures_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

{
  defaultSelector:: defaultSelector,
  workerFeedRate: workerFeedRate,
  workerFeedFailuresRate: workerFeedFailuresRate,
  workerSlots: workerSlots,
  workerSlotOperationsRate: workerSlotOperationsRate,
  workerProcessingFailuresRate: workerProcessingFailuresRate,
  workerHealthCheckFailuresRate: workerHealthCheckFailuresRate,
}
