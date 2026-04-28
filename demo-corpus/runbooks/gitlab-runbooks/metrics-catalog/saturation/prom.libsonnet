local recordedQuantiles = (import 'servicemetrics/resource_saturation_point.libsonnet').recordedQuantiles;

local defaults = {
  baseURL: 'https://thanos.ops.gitlab.net',
  defaultSelectors: {
    env: 'gprd',
    environment: 'gprd',
    stage: ['main', ''],
  },
  serviceLabel: 'type',
  queryTemplates: std.foldl(
    function(memo, quantile)
      local quantilePercent = quantile * 100;
      local formatConfig = { quantilePercent: quantilePercent, selectorPlaceholder: '%s' };
      memo {
        ['quantile%d_1w' % [quantilePercent]]: 'max(gitlab_component_saturation:ratio_quantile%(quantilePercent)d_1w{%(selectorPlaceholder)s})' % formatConfig,
        ['quantile%d_1h' % [quantilePercent]]: 'max(gitlab_component_saturation:ratio_quantile%(quantilePercent)d_1h{%(selectorPlaceholder)s})' % formatConfig,
      },
    recordedQuantiles,
    {}
  ) {
    // Here we're overriding the quantile95_1h again to _not_ use a recording, even though we can.
    // Ideally, we'd use the recorded quantile in tamland, making each query cheaper to make,
    // but doing that would bust the tamland-data-cache in parquet files.
    quantile95_1h: 'max(quantile_over_time(0.95, gitlab_component_saturation:ratio{%s}[1h]))',
  },
};

{
  defaults:: defaults,
}
