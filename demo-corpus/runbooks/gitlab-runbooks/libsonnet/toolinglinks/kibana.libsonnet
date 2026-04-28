local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'kibana', type:: 'log' });
local coreDashboards = import './core_dashboards.libsonnet';
local metricsConfig = import 'gitlab-metrics-config.libsonnet';

local indexCatalog = metricsConfig.indexCatalog;

// These are default prometheus label mappings, for mapping
// between prometheus labels and their equivalent ELK fields
// We know that these fields exist on most of our structured logs
// so we can safely map from the given labels to the fields in all cases
local defaultPrometheusLabelMappings = {
  type: 'json.type',
  stage: 'json.stage',
};

local linkGenerator = (import 'elasticlinkbuilder/elasticsearch_links.libsonnet').linkGenerator(indexCatalog, defaultPrometheusLabelMappings);

{
  kibana(
    title,
    index,
    type=null,
    tag=null,
    shard=null,
    message=null,
    slowRequestSeconds=null,
    matches={},
    filters=[],
    includeMatchersForPrometheusSelector=true
  )::
    function(options)
      coreDashboards.dashboardLinks(
        title,
        index,
        type,
        tag,
        shard,
        message,
        slowRequestSeconds,
        matches,
        filters,
        includeMatchersForPrometheusSelector,
        options,
        linkGenerator,
        toolingLinkDefinition,
        dashboardTechName='Kibana',
        fieldPrefix='json.'
      ),
}
