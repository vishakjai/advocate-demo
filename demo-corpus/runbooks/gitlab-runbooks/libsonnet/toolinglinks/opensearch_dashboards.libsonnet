local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'opensearch', type:: 'log' });
local coreDashboards = import './core_dashboards.libsonnet';
local metricsConfig = import 'gitlab-metrics-config.libsonnet';
local indexCatalog = metricsConfig.indexCatalog;
local toolingLinksConfig = metricsConfig.options.toolingLinks;

local linkGenerator = (import 'elasticlinkbuilder/elasticsearch_links.libsonnet').linkGenerator(indexCatalog, {});

{
  opensearchDashboards(
    title,
    index,
    containerName=null,
    type=null,
    tag=null,
    shard=null,
    message=null,
    slowRequestSeconds=null,
    matches={},
    filters=[],
    includeMatchersForPrometheusSelector=false
  )::
    local fullMatches = matches +
                        if containerName != null then { 'kubernetes.container_name': containerName } else {};

    function(options)
      if toolingLinksConfig.opensearchHostname != null then
        coreDashboards.dashboardLinks(
          title,
          index,
          type,
          tag,
          shard,
          message,
          slowRequestSeconds,
          fullMatches,
          filters,
          includeMatchersForPrometheusSelector,
          options,
          linkGenerator,
          toolingLinkDefinition,
          dashboardTechName='Opensearch',
          fieldPrefix=''
        )
      else
        [],
}
