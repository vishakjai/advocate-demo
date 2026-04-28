local layout = import 'grafana/layout.libsonnet';
local toolingLinkDefinition = (import 'toolinglinks/tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'kibana', type:: 'log' });
local elasticsearchLinks = import 'elasticlinkbuilder/elasticsearch_links.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';

{
  shardWorkloads(querySelector, startRow, datalink=null)::
    local formatConfig = {
      querySelector: querySelector,
    };

    local panels =
      [
        panel.saturationTimeSeries(
          title='Sidekiq Worker Saturation by Shard',
          description='Shows sidekiq worker saturation. Once saturated, all sidekiq workers will be busy processing jobs, and any new jobs that arrive will queue. Lower is better.',
          query=|||
            gitlab_component_saturation:ratio{%(querySelector)s, component="sidekiq_shard_workers"}
          ||| % formatConfig,
          legendFormat='{{ shard }}',
          intervalFactor=1,
          linewidth=2,
        ),
      ];

    local panelsWithDataLink =
      if datalink != null then
        [p.addDataLink(datalink) for p in panels]
      else
        panels;

    layout.grid(panelsWithDataLink, cols=2, rowHeight=10, startRow=startRow),

  // matcherField is the field used from template variable.
  latencyKibanaViz(index, title, matcherField, percentile, templateField=matcherField)::
    function(options)
      [
        toolingLinkDefinition({
          title: title,
          url: elasticsearchLinks.buildElasticLinePercentileVizURL(
            index,
            [matching.matchRegexFilter('json.%s.keyword' % matcherField, '${%s:regex}' % templateField)],
            splitSeries=true,
            percentile=percentile
          ),
          type:: 'chart',
        }),
      ],
}
