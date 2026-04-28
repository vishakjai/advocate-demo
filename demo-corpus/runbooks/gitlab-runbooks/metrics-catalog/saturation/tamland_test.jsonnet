local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local saturation = import 'servicemetrics/saturation-resources.libsonnet';
local manifest = import 'tamland.jsonnet';
local test = import 'test.libsonnet';

local resourceSaturationPoint = metricsCatalog.resourceSaturationPoint;

local saturationPoints = {
  michael_scott: resourceSaturationPoint({
    title: 'Michael Scott',
    severity: 's4',
    horizontallyScalable: true,
    capacityPlanning: {
      strategy: 'exclude',
    },
    appliesTo: ['thanos', 'web', 'api'],
    description: |||
      Just Mr Tamland chart
    |||,
    grafana_dashboard_uid: 'just testing',
    resourceLabels: ['name'],
    query: |||
      memory_used_bytes{area="heap", %(selector)s}
      /
      memory_max_bytes{area="heap", %(selector)s}
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
  jimbo: resourceSaturationPoint({
    title: 'Jimbo',
    severity: 's4',
    horizontallyScalable: true,
    capacityPlanning: {
      strategy: 'exclude',
    },
    appliesTo: ['thanos', 'redis'],
    description: |||
      Just Mr Jimbo
    |||,
    grafana_dashboard_uid: 'just testing',
    resourceLabels: ['name'],
    query: |||
      memory_used_bytes{area="heap", %(selector)s}
      /
      memory_max_bytes{area="heap", %(selector)s}
    |||,
    slos: {
      soft: 0.80,
      hard: 0.90,
    },
  }),
};

test.suite({
  testDefaults: {
    actual: manifest.defaults,
    expectThat: {
      local promFields = std.objectFields(self.actual.prometheus),
      result: std.objectHas(self.actual, 'prometheus')
              && promFields == ['baseURL', 'defaultSelectors', 'queryTemplates', 'serviceLabel'],
      description: 'Expect object to have default configurations',
    },
  },
  testHasSaturationPoints: {
    actual: manifest,
    expectThat: {
      result: std.objectHas(self.actual, 'saturationPoints') == true,
      description: 'Expect object to have saturationPoints field',
    },
  },
  testHasServices: {
    local servicesHaveExpectedFields = std.map(
      function(name)
        local fields = std.objectFields(self.actual.services[name]);
        local expectedFields = [
          'capacityPlanning',
          'label',
          'name',
          'overviewDashboard',
          'owner',
          'resourceDashboard',
          'shards',
        ];
        std.all(
          std.map(
            function(field)
              std.member(expectedFields, field),
            fields
          )
        ),
      std.objectFields(self.actual.services)
    ),
    actual: manifest,
    expectThat: {
      result: std.all(servicesHaveExpectedFields),
      description: 'Expect object to have serviceCatalog fields',
    },
  },
  testHasServiceCatalogTeamsField: {
    actual: manifest,
    expectThat: {
      result: std.objectHas(self.actual, 'teams') == true,
      description: 'Expect object to have serviceCatalog.teams field',
    },
  },
  testHasServiceCatalogTeamsFields: {
    actual: manifest,
    expectThat: {
      result: std.sort(std.objectFields(self.actual.teams[0])) == std.sort(['name', 'label', 'manager']),
      description: 'Expect object to have serviceCatalog.teams fields',
    },
  },
  testReportHasRunwayServices: {
    actual: manifest,
    expectThat: {
      local runwayPage = std.filter(function(page) page.path == 'runway.md', self.actual.report.pages)[0],
      local runwayServices = std.split(runwayPage.service_pattern, '|'),
      result: std.member(runwayServices, 'ai-gateway'),
      description: 'Expect object to dynamically include Runway provisioned services',
    },
  },
  testQueryFormatConfigInterpolatedInDynamicLookupQuery: {
    // Verifies that queryFormatConfig values are interpolated into
    // saturation_dimension_dynamic_lookup_query while preserving %(selector)s.
    // See: https://gitlab.com/gitlab-com/gl-infra/observability/team/-/issues/4484
    actual: manifest.saturationPoints.sidekiq_kube_container_rss_request,
    expectThat: {
      local dynamicQuery = self.actual.capacityPlanning.saturation_dimension_dynamic_lookup_query,
      local hasNoShardSelectorPlaceholder = std.length(std.findSubstr('%(shardSelector)s', dynamicQuery)) == 0,
      local hasSelectorPlaceholder = std.length(std.findSubstr('%(selector)s', dynamicQuery)) > 0,
      local hasInterpolatedShardFilter = std.length(std.findSubstr('shard!~', dynamicQuery)) > 0,
      result: hasNoShardSelectorPlaceholder && hasSelectorPlaceholder && hasInterpolatedShardFilter,
      description: 'Expect queryFormatConfig to be interpolated while preserving %(selector)s',
    },
  },
  testAllDynamicLookupQueriesHaveOnlySelectorPlaceholder: {
    // Verifies that all saturation_dimension_dynamic_lookup_query fields only contain
    // %(selector)s placeholder and no other uninterpolated placeholders.
    // See: https://gitlab.com/gitlab-com/gl-infra/observability/team/-/issues/4484
    actual: manifest.saturationPoints,
    expectThat: {
      local saturationPointsWithDynamicQuery = std.filter(
        function(name) std.objectHas(self.actual[name].capacityPlanning, 'saturation_dimension_dynamic_lookup_query'),
        std.objectFields(self.actual)
      ),
      local validateQuery(name) =
        local query = self.actual[name].capacityPlanning.saturation_dimension_dynamic_lookup_query;
        local hasSelectorPlaceholder = std.length(std.findSubstr('%(selector)s', query)) > 0;
        local queryWithoutSelector = std.strReplace(query, '%(selector)s', '');
        local hasOtherPlaceholders = std.length(std.findSubstr('%(', queryWithoutSelector)) > 0;
        hasSelectorPlaceholder && !hasOtherPlaceholders,
      result: std.all(std.map(validateQuery, saturationPointsWithDynamicQuery)),
      description: 'Expect all saturation_dimension_dynamic_lookup_query to contain only %(selector)s placeholder',
    },
  },
})
