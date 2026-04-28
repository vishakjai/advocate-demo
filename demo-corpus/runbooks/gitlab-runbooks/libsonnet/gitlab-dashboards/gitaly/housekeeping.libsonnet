local panel = import 'grafana/time-series/panel.libsonnet';
local target = import 'grafana/time-series/target.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

{
  // OptimizeRepository metrics
  performed_optimizations(selectorHash)::
    panel.timeSeries(
      title='OptimizeRepository: Performed Optimizations',
      description='The OptimizeRepository RPC is combining all the different maintenance tasks like repacking objects, repacking references or pruning objects into a single RPC. This metric keeps track of which subtasks get executed as part of OptimizeRepository to improve visibility into what the RPC does.',
      query=|||
        sum(rate(gitaly_housekeeping_tasks_total{%(selector)s}[$__rate_interval])) by (housekeeping_task)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{housekeeping_task}}',
      interval='1m',
      linewidth=1,
      legend_show=true,
      format='reqps',
    ),

  // Main dashboard variants that break down by fqdn
  housekeeping_tasks_total_by_fqdn(selectorHash)::
    panel.timeSeries(
      title='Housekeeping Tasks (Total)',
      description='Total rate of housekeeping tasks performed across all task types, broken down by Gitaly node.',
      query=|||
        sum(rate(gitaly_housekeeping_tasks_total{%(selector)s}[$__rate_interval])) by (fqdn)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{fqdn}}',
      interval='1m',
      linewidth=1,
      legend_show=true,
      format='reqps',
      drawStyle='bars',
      stack=true,
    ),

  housekeeping_failures_by_fqdn(selectorHash)::
    panel.timeSeries(
      title='Housekeeping Failures',
      description='Rate of housekeeping task failures by node and task type. Zero failure rates are filtered out for clarity.',
      query=|||
        sum(rate(gitaly_housekeeping_tasks_total{%(selector)s, status="failure"}[$__rate_interval])) by (fqdn, housekeeping_task) > 0
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{fqdn}} - {{housekeeping_task}}',
      interval='1m',
      linewidth=1,
      legend_show=true,
      format='reqps',
      drawStyle='bars',
      stack=true,
    ),

  housekeeping_failures(selectorHash)::
    panel.timeSeries(
      title='Housekeeping Failures',
      description='Rate of housekeeping task failures by task type.',
      query=|||
        sum(rate(gitaly_housekeeping_tasks_total{%(selector)s, status="failure"}[$__rate_interval])) by (housekeeping_task)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{housekeeping_task}}',
      interval='1m',
      linewidth=1,
      legend_show=true,
      format='reqps',
    ),

  per_optimization_latencies(selectorHash)::
    panel.timeSeries(
      title='OptimizeRepository: Per-Optimization Latencies',
      description='The OptimizeRepository RPC is combining all the different maintenance tasks like repacking objects, repacking references or pruning objects into a single RPC. This metric keeps track of the latency of each of the subtasks executed as part of OptimizeRepository to improve visibility into what the RPC does.',
      query=|||
        histogram_quantile(0.99, sum(rate(gitaly_housekeeping_tasks_latency_bucket{%(selector)s}[$__rate_interval])) by (le,housekeeping_task))
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{housekeeping_task}} (P99)',
      interval='1m',
      linewidth=1,
      legend_show=true,
      format='s',
    )
    .addTarget(
      target.prometheus(
        'histogram_quantile(0.95, sum(rate(gitaly_housekeeping_tasks_latency_bucket{%(selector)s}[$__rate_interval])) by (le,housekeeping_task))' % { selector: selectors.serializeHash(selectorHash) },
        legendFormat='{{housekeeping_task}} (P95)',
        interval='1m',
      )
    ),

  accumulated_optimization_timings(selectorHash)::
    panel.timeSeries(
      title='OptimizeRepository: Accumulated Per-Optimization Timings',
      description='The OptimizeRepository RPC is combining all the different maintenance tasks like repacking objects, repacking references or pruning objects into a single RPC. This metric keeps track of the accumulated time spent in each of the subtasks executed as part of OptimizeRepository to improve visibility into what the RPC does.',
      query=|||
        sum(increase(gitaly_housekeeping_tasks_latency_sum{%(selector)s}[$__rate_interval])) by (housekeeping_task)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{housekeeping_task}}',
      interval='1m',
      linewidth=1,
      legend_show=true,
      format='s',
    ),

  stale_file_pruning(selectorHash)::
    panel.timeSeries(
      title='Stale File Pruning',
      description="Gitaly's housekeeping tasks prune files which are not needed for normal operations or which have been left behind by Git processes due to reasons like crashes. This metric counts the number of files and directories we are pruning as part of this housekeeping task.",
      query=|||
        sum(rate(gitaly_housekeeping_pruned_files_total{%(selector)s}[$__rate_interval])) by (filetype)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{filetype}}',
      interval='1m',
      linewidth=1,
      legend_show=true,
    ),

  data_structure_existence(selectorHash)::
    panel.timeSeries(
      title='Data Structure Existence',
      description='This graph reports the percentage of repositories for which the given data structure is found to exist. Existence of data structures is reported during repository housekeeping.',
      query=|||
        sum(increase(gitaly_housekeeping_data_structure_existence_total{exists="true",%(selector)s}[$__rate_interval])) by (data_structure)
        /
        sum(increase(gitaly_housekeeping_data_structure_existence_total{%(selector)s}[$__rate_interval])) by (data_structure)
      ||| % { selector: selectors.serializeHash(selectorHash) },
      legendFormat='{{data_structure}}',
      interval='1m',
      linewidth=1,
      legend_show=true,
      format='percentunit',
    ),

  time_since_last_optimization(selectorHash)::
    local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
    local heatmapPanel = grafana.heatmapPanel;

    heatmapPanel.new(
      title='Time Since Last Optimization',
      description='Distribution of time since data structures were last optimized. This helps identify repositories that may need housekeeping attention.',
      datasource='$PROMETHEUS_DS',
      yAxis_format='dtdurations',
      yAxis_decimals=0,
      dataFormat='tsbuckets',
      color_mode='spectrum',
      color_cardColor='#b4ff00',
      color_colorScheme='Spectral',
      color_exponent=0.5,
      legend_show=false,
    ).addTarget(
      {
        expr: 'sum(increase(gitaly_housekeeping_time_since_last_optimization_seconds_bucket{%(selector)s}[$__rate_interval])) by (le)' % { selector: selectors.serializeHash(selectorHash) },
        format: 'heatmap',
        legendFormat: '{{le}}',
        interval: '1m',
      }
    ),

  data_structure_size_heatmap(selectorHash, data_structure)::
    local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
    local heatmapPanel = grafana.heatmapPanel;

    heatmapPanel.new(
      title='Size of %s' % data_structure,
      description='Total size distribution of the %s data structure. This data is reported for a repository whenever it is getting optimized.' % data_structure,
      datasource='$PROMETHEUS_DS',
      yAxis_format='decbytes',
      yAxis_decimals=0,
      dataFormat='tsbuckets',
      color_mode='spectrum',
      color_cardColor='#blue',
      color_colorScheme='Spectral',
      color_exponent=0.5,
      legend_show=false,
    ).addTarget(
      {
        expr: 'sum(increase(gitaly_housekeeping_data_structure_size_bucket{%(selector)s,data_structure="%(data_structure)s"}[$__rate_interval])) by (le)' % { selector: selectors.serializeHash(selectorHash), data_structure: data_structure },
        format: 'heatmap',
        legendFormat: '{{le}}',
        interval: '1m',
      }
    ),

  data_structure_count_heatmap(selectorHash, data_structure)::
    local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
    local heatmapPanel = grafana.heatmapPanel;

    heatmapPanel.new(
      title='Count of %s' % data_structure,
      description='Number of instances distribution of the %s data structure. This data is reported for a repository whenever it is getting optimized.' % data_structure,
      datasource='$PROMETHEUS_DS',
      yAxis_format='short',
      yAxis_decimals=0,
      dataFormat='tsbuckets',
      color_mode='spectrum',
      color_cardColor='#purple',
      color_colorScheme='Spectral',
      color_exponent=0.5,
      legend_show=false,
    ).addTarget(
      {
        expr: 'sum(increase(gitaly_housekeeping_data_structure_count_bucket{%(selector)s,data_structure="%(data_structure)s"}[$__rate_interval])) by (le)' % { selector: selectors.serializeHash(selectorHash), data_structure: data_structure },
        format: 'heatmap',
        legendFormat: '{{le}}',
        interval: '1m',
      }
    ),

  // Generate paired count and size heatmap panels for each data structure
  data_structure_paired_panels(selectorHash, data_structure)::
    [
      self.data_structure_count_heatmap(selectorHash, data_structure),
      self.data_structure_size_heatmap(selectorHash, data_structure),
    ],

  // Generate all data structure heatmap panels grouped by data structure
  data_structure_heatmaps(selectorHash)::
    local common_data_structures = [
      'loose_objects_recent',
      'loose_objects_stale',
      'packed_references',
      'packfiles',
      'packfiles_cruft',
      'packfiles_keep',
    ];

    std.flattenArrays([
      self.data_structure_paired_panels(selectorHash, ds)
      for ds in common_data_structures
    ]),

}
