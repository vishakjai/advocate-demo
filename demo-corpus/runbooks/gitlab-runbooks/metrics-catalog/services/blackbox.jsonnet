local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local gaugeMetric = metricsCatalog.gaugeMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

metricsCatalog.serviceDefinition({
  type: 'blackbox',
  tier: 'inf',
  tenants: ['gitlab-gprd', 'gitlab-gstg', 'gitlab-pre'],

  serviceDependencies: {
    monitoring: true,
  },

  serviceLevelIndicators: {
    probe: {
      userImpacting: false,
      featureCategory: 'not_owned',
      trafficCessationAlertConfig: true,

      requestRate: gaugeMetric(
        gauge='probe_success',
        selector={
          job: 'scrapeConfig/monitoring/prometheus-agent-blackbox',
          module: 'http_2xx',
        }
      ),

      significantLabels: ['instance'],

      toolingLinks: [
        toolingLinks.kibana(title='Blackbox', index='monitoring_gprd'),
      ],
    },
  },
})
