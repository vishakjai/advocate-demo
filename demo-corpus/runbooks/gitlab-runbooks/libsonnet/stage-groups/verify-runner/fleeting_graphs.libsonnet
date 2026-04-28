local panels = import './panels.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

local defaultSelector = 'environment=~"$environment", stage=~"$stage", shard=~"${shard:pipe}"';

local provisionerInstancesSaturation(selector=defaultSelector) =
  panel.timeSeries(
    'Fleeting instances saturation',
    description='Ratio of (running + creating + deleting) instances to max_instances. Approaching 100% means the pool is full and new VMs cannot be created until old ones are deleted.',
    legendFormat='{{shard}}',
    format='percentunit',
    query=|||
      sum by(shard) (
        fleeting_provisioner_instances{state=~"running|creating|deleting", %(selector)s}
      )
      /
      sum by(shard) (
        fleeting_provisioner_max_instances{%(selector)s}
      )
    ||| % { selector: selector },
  );

local provisionerInstancesStates(selector=defaultSelector) =
  panel.timeSeries(
    'Fleeting instances states',
    description='Count of fleeting instances in each lifecycle state (requested, creating, pending, running, deleting etc.). A growing "deleting" count without a drop in "running" can indicate stuck deletions.',
    legendFormat='{{shard}}: {{state}}',
    format='short',
    query=|||
      sum by(shard, state) (
        fleeting_provisioner_instances{%(selector)s}
      )
    ||| % { selector: selector },
  );

local provisionerMissedUpdates(selector=defaultSelector) =
  panel.timeSeries(
    'Fleeting missed updates rate',
    description='Rate of skipped provisioner reconciliation cycles. Should be near zero; sustained non-zero values indicate the provisioner cannot keep up with its update loop.',
    legendFormat='{{shard}}',
    format='ops',
    query=|||
      sum by(shard) (
        rate(
          fleeting_provisioner_missed_updates_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local provisionerInstanceOperationsRate(selector=defaultSelector) =
  panel.timeSeries(
    'Fleeting instance operations rate',
    description='Rate of provisioner instance lifecycle operations (create, delete, update, etc.) broken down by shard and operation type.',
    legendFormat='{{shard}}: {{operation}}',
    format='ops',
    query=|||
      sum by(shard, operation) (
        rate(
          fleeting_provisioner_instance_operations_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local provisionerInternalOperationsRate(selector=defaultSelector) =
  panel.timeSeries(
    'Fleeting internal operations rate',
    description='Rate of internal provisioner bookkeeping operations (e.g. reconciliation, state tracking) broken down by shard and operation type.',
    legendFormat='{{shard}}: {{operation}}',
    format='ops',
    query=|||
      sum by(shard, operation) (
        rate(
          fleeting_provisioner_internal_operations_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local provisionerCreationTiming(selector=defaultSelector) =
  panels.heatmap(
    'Fleeting instance creation timing',
    |||
      sum by (le) (
        rate(
          fleeting_provisioner_instance_creation_time_seconds_bucket{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
    color_mode='spectrum',
    color_colorScheme='Greens',
    legend_show=true,
    intervalFactor=2,
    description='Distribution of time taken to create a new VM. Increases typically point to cloud provider slowness or quota issues.',
  );

local provisionerIsRunningTiming(selector=defaultSelector) =
  panels.heatmap(
    'Fleeting instance is_running timing',
    |||
      sum by (le) (
        rate(
          fleeting_provisioner_instance_is_running_time_seconds_bucket{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
    color_mode='spectrum',
    color_colorScheme='Blues',
    legend_show=true,
    intervalFactor=2,
    description='Distribution of time from VM creation to the instance reporting as running. Longer durations indicate slow VM boot or cloud provider delays.',
  );

local provisionerDeletionTiming(selector=defaultSelector) =
  panels.heatmap(
    'Fleeting instance deletion timing',
    |||
      sum by (le) (
        rate(
          fleeting_provisioner_instance_deletion_time_seconds_bucket{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
    color_mode='spectrum',
    color_colorScheme='Reds',
    legend_show=true,
    intervalFactor=2,
    description='Distribution of time taken to delete a VM. Slow deletions reduce the rate at which capacity can be recycled.',
  );

local provisionerInstanceLifeDuration(selector=defaultSelector) =
  panels.heatmap(
    'Fleeting instance life duration',
    |||
      sum by (le) (
        rate(
          fleeting_provisioner_instance_life_duration_seconds_bucket{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
    color_mode='spectrum',
    color_colorScheme='Purples',
    legend_show=true,
    intervalFactor=2,
    description='Distribution of total VM lifetime from creation to deletion. Useful for understanding instance turnover rate and whether VMs are being retired on schedule.',
  );

local taskscalerTasksSaturation(selector=defaultSelector) =
  panel.timeSeries(
    'Taskscaler tasks saturation',
    description='Ratio of active tasks (excluding idle/reserved) to total task capacity (max_instances × max_tasks_per_instance). High saturation means the taskscaler is running near its configured ceiling.',
    legendFormat='{{shard}}',
    format='percentunit',
    query=|||
      sum by(shard) (
        fleeting_taskscaler_tasks{%(selector)s, state!~"idle|reserved"}
      )
      /
      sum by(shard) (
        fleeting_provisioner_max_instances{%(selector)s}
        *
        fleeting_taskscaler_max_tasks_per_instance{%(selector)s}
      )
    ||| % { selector: selector },
  );

local taskscalerMaxUseCountPerInstance(selector=defaultSelector) =
  panel.timeSeries(
    'Taskscaler max use count per instance',
    description='Configured maximum number of tasks an instance will execute before being retired and replaced. Changes here reflect config updates.',
    legendFormat='{{shard}}',
    format='short',
    query=|||
      sum by(shard) (
        fleeting_taskscaler_max_use_count_per_instance{%(selector)s}
      )
    ||| % { selector: selector },
  );

local taskscalerOperationsRate(selector=defaultSelector) =
  panel.timeSeries(
    'Taskscaler operations rate',
    description='Rate of taskscaler task operations (acquire, release, etc.) broken down by shard and operation type.',
    legendFormat='{{shard}}: {{operation}}',
    format='ops',
    query=|||
      sum by(shard, operation) (
        rate(
          fleeting_taskscaler_task_operations_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local taskscalerOperationsFailure(selector=defaultSelector) =
  panel.timeSeries(
    'Taskscaler operations failure',
    description='Rate of taskscaler capacity reservation failures.\n\n- **reserve_iop_capacity_failure**: zero capacity whatsoever — both available and potential are ≤ 0.\n- **reserve_available_capacity_failure**: no immediately available capacity (available ≤ 0) but potential capacity exists (VMs could be created).',
    legendFormat='{{shard}}: {{operation}}',
    format='ops',
    query=|||
      sum by(shard, operation) (
        rate(
          fleeting_taskscaler_task_operations_total{%(selector)s, operation=~"reserve_available_capacity_failure|reserve_iop_capacity_failure"}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local taskscalerIdleRatio(selector=defaultSelector) =
  panel.timeSeries(
    'Taskscaler idle ratio',
    description='Percentage of taskscaler instances sitting idle per shard. High idle ratios indicate over-provisioning — useful for cost and performance tuning.',
    legendFormat='{{shard}}',
    format='percentunit',
    query=|||
      sum by(shard) (fleeting_taskscaler_tasks{%(selector)s, state="idle"})
      /
      sum by(shard) (fleeting_taskscaler_tasks{%(selector)s})
    ||| % { selector: selector },
    min=0,
    max=1,
  );

local taskscalerTasks(selector=defaultSelector) =
  panel.timeSeries(
    'Taskscaler tasks',
    description='Current task count by state (idle → reserved → acquired → released). Shows how demand is distributed across the task lifecycle.',
    legendFormat='{{shard}}: {{state}}',
    format='short',
    query=|||
      sum by(shard, state) (
        fleeting_taskscaler_tasks{%(selector)s}
      )
    ||| % { selector: selector },
  );

local taskscalerInstanceReadinessTiming(selector=defaultSelector) =
  panels.heatmap(
    'Taskscaler instance readiness timing',
    |||
      sum by (le) (
        rate(
          fleeting_taskscaler_task_instance_readiness_time_seconds_bucket{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
    color_mode='spectrum',
    color_colorScheme='Oranges',
    legend_show=true,
    intervalFactor=2,
    description='Distribution of time from VM creation until the taskscaler considers the instance ready to accept tasks.',
  );

local taskscalerScaleOperationsRate(selector=defaultSelector) =
  panel.timeSeries(
    'Taskscaler scale operations rate',
    description='Rate of scale-up and scale-down decisions made by the taskscaler. Imbalanced rates may indicate oscillation or a misconfigured scaling policy.',
    legendFormat='{{shard}}: {{operation}}',
    format='ops',
    query=|||
      sum by(shard, operation) (
        rate(
          fleeting_taskscaler_scale_operations_total{%(selector)s}[$__rate_interval]
        )
      )
    ||| % { selector: selector },
  );

local taskscalerDesiredInstances(selector=defaultSelector) =
  panel.timeSeries(
    'Taskscaler desired instances',
    description='Number of VMs the taskscaler currently wants to maintain based on demand. Compare with actual instance counts to identify scaling lag.',
    legendFormat='{{shard}}',
    format='short',
    min=null,
    query=|||
      sum by(shard) (
        fleeting_taskscaler_desired_instances{%(selector)s}
      )
    ||| % { selector: selector },
  );

{
  defaultSelector:: defaultSelector,
  provisionerInstancesSaturation:: provisionerInstancesSaturation,
  provisionerInstancesStates:: provisionerInstancesStates,
  provisionerMissedUpdates:: provisionerMissedUpdates,
  provisionerInstanceOperationsRate:: provisionerInstanceOperationsRate,
  provisionerInternalOperationsRate:: provisionerInternalOperationsRate,
  provisionerCreationTiming:: provisionerCreationTiming,
  provisionerIsRunningTiming:: provisionerIsRunningTiming,
  provisionerDeletionTiming:: provisionerDeletionTiming,
  provisionerInstanceLifeDuration:: provisionerInstanceLifeDuration,
  taskscalerTasksSaturation:: taskscalerTasksSaturation,
  taskscalerMaxUseCountPerInstance:: taskscalerMaxUseCountPerInstance,
  taskscalerOperationsRate:: taskscalerOperationsRate,
  taskscalerOperationsFailure:: taskscalerOperationsFailure,
  taskscalerIdleRatio:: taskscalerIdleRatio,
  taskscalerTasks:: taskscalerTasks,
  taskscalerDesiredInstances:: taskscalerDesiredInstances,
  taskscalerInstanceReadinessTiming:: taskscalerInstanceReadinessTiming,
  taskscalerScaleOperationsRate:: taskscalerScaleOperationsRate,
}
