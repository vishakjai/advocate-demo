local matching = import 'elasticlinkbuilder/matching.libsonnet';

{
  dashboardLinks: function(title,
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
                           dashboardTechName,
                           fieldPrefix='')
    local supportsRequests = linkGenerator.indexSupportsRequestGraphs(index);
    local supportsFailures = linkGenerator.indexSupportsFailureQueries(index);
    local supportsLatencies = linkGenerator.indexSupportsLatencyQueries(index);
    local includeSlowRequests = supportsLatencies &&
                                (slowRequestSeconds != null || linkGenerator.indexHasSlowRequestFilter(index));

    local allFilters =
      filters +
      (
        if type == null then
          []
        else
          [matching.matchFilter(fieldPrefix + 'type.keyword', type)]
      )
      +
      (
        if tag == null then
          []
        else
          [matching.matchFilter(fieldPrefix + 'tag.keyword', tag)]
      )
      +
      (
        if shard == null then
          []
        else
          [matching.matchFilter(fieldPrefix + 'shard.keyword', shard)]
      )
      +
      (
        if message == null then
          []
        else
          [matching.matchFilter(fieldPrefix + 'message.keyword', message)]
      )
      +
      matching.matchers(matches)
      +
      (
        if includeMatchersForPrometheusSelector then
          linkGenerator.getMatchersForPrometheusSelectorHash(index, options.prometheusSelectorHash)
        else
          []
      );

    [
      toolingLinkDefinition({
        title: '📖 ' + dashboardTechName + ': ' + title + ' logs',
        url: linkGenerator.buildElasticDiscoverSearchQueryURL(index, allFilters),
      }),
    ]
    +
    (
      if includeSlowRequests then
        [
          toolingLinkDefinition({
            title: '📖 ' + dashboardTechName + ': ' + title + ' slow request logs',
            url: linkGenerator.buildElasticDiscoverSlowRequestSearchQueryURL(index, allFilters, slowRequestSeconds=slowRequestSeconds),
          }),
        ]
      else []
    )
    +
    (
      if supportsFailures then
        [
          toolingLinkDefinition({
            title: '📖 ' + dashboardTechName + ': ' + title + ' failed request logs',
            url: linkGenerator.buildElasticDiscoverFailureSearchQueryURL(index, allFilters),
          }),
        ]
      else
        []
    )
    +
    (
      if supportsRequests then
        [
          toolingLinkDefinition({
            title: '📈 ' + dashboardTechName + ': ' + title + ' requests',
            url: linkGenerator.buildElasticLineCountVizURL(index, allFilters),
            type:: 'chart',
          }),
        ]
      else
        []
    )
    +
    (
      if supportsFailures then
        [
          toolingLinkDefinition({
            title: '📈 ' + dashboardTechName + ': ' + title + ' failed requests',
            url: linkGenerator.buildElasticLineFailureCountVizURL(index, allFilters),
            type:: 'chart',
          }),
        ]
      else
        []
    )
    +
    (
      if supportsLatencies then
        [
          toolingLinkDefinition({
            title: '📈 ' + dashboardTechName + ': ' + title + ' sum latency aggregated',
            url: linkGenerator.buildElasticLineTotalDurationVizURL(index, allFilters, splitSeries=false),
            type:: 'chart',
          }),
          toolingLinkDefinition({
            title: '📈 ' + dashboardTechName + ': ' + title + ' sum latency aggregated (split)',
            url: linkGenerator.buildElasticLineTotalDurationVizURL(index, allFilters, splitSeries=true),
            type:: 'chart',
          }),
          toolingLinkDefinition({
            title: '📈 ' + dashboardTechName + ': ' + title + ' percentile latency aggregated',
            url: linkGenerator.buildElasticLinePercentileVizURL(index, allFilters, splitSeries=false),
            type:: 'chart',
          }),
          toolingLinkDefinition({
            title: '📈 ' + dashboardTechName + ': ' + title + ' percentile latency aggregated (split)',
            url: linkGenerator.buildElasticLinePercentileVizURL(index, allFilters, splitSeries=true),
            type:: 'chart',
          }),
        ]
      else
        []
    ),
}
