local resourceSaturationPoint = (import './resource_saturation_point.libsonnet').resourceSaturationPoint;
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

local baseDefinition = {
  title: 'Test',
  severity: 's4',
  horizontallyScalable: false,
  appliesTo: ['web'],
  description: 'test resource',
  grafana_dashboard_uid: 'test',
  resourceLabels: ['name'],
  query: 'test{%(selector)s}',
  slos: { soft: 0.80, hard: 0.90 },
};

test.suite({
  testCapacityPlanningForTamlandWithoutDynamicLookup: {
    local point = resourceSaturationPoint(baseDefinition {
      capacityPlanning: { strategy: 'exclude' },
    }),
    actual: point.getCapacityPlanningForTamland(),
    expect: {
      strategy: 'exclude',
      forecast_days: 90,
      historical_days: 400,
      changepoints_count: 25,
    },
  },

  testCapacityPlanningForTamlandPreservesSelectorPlaceholder: {
    local point = resourceSaturationPoint(baseDefinition {
      capacityPlanning: {
        strategy: 'exclude',
        saturation_dimension_dynamic_lookup_query: 'count by(name) (foo{%(selector)s})',
      },
    }),
    actual: point.getCapacityPlanningForTamland(),
    expectThat: {
      local query = self.actual.saturation_dimension_dynamic_lookup_query,
      result: std.length(std.findSubstr('%(selector)s', query)) == 1,
      description: 'Expect %(selector)s to be preserved in dynamic lookup query',
    },
  },

  testCapacityPlanningForTamlandInterpolatesQueryFormatConfig: {
    local point = resourceSaturationPoint(baseDefinition {
      query: 'test{%(selector)s, %(shardSelector)s}',
      queryFormatConfig: { shardSelector: { shard: { ne: 'throttled' } } },
      capacityPlanning: {
        strategy: 'exclude',
        saturation_dimension_dynamic_lookup_query: 'count by(name) (foo{%(selector)s, %(shardSelector)s})',
      },
    }),
    actual: point.getCapacityPlanningForTamland(),
    expectThat: {
      local query = self.actual.saturation_dimension_dynamic_lookup_query,
      local hasNoShardSelectorPlaceholder = std.length(std.findSubstr('%(shardSelector)s', query)) == 0,
      local hasSelectorPlaceholder = std.length(std.findSubstr('%(selector)s', query)) == 1,
      local hasInterpolatedShardFilter = std.length(std.findSubstr('shard!="throttled"', query)) > 0,
      result: hasNoShardSelectorPlaceholder && hasSelectorPlaceholder && hasInterpolatedShardFilter,
      description: 'Expect queryFormatConfig to be interpolated while preserving: result was `%s`' % [query],
    },
  },

  testRawQueryForTamlandPreservesSelectorPlaceholder: {
    local point = resourceSaturationPoint(baseDefinition {
      capacityPlanning: { strategy: 'exclude' },
    }),
    actual: point.getRawQueryForTamland(),
    expectThat: {
      result: std.length(std.findSubstr('%(selector)s', self.actual)) > 0,
      description: 'Expect %(selector)s to be preserved in raw query',
    },
  },

  testRawQueryForTamlandInterpolatesQueryFormatConfig: {
    local point = resourceSaturationPoint(baseDefinition {
      query: 'test{%(selector)s, %(shardSelector)s}',
      queryFormatConfig: { shardSelector: { shard: { ne: 'throttled' } } },
      capacityPlanning: { strategy: 'exclude' },
    }),
    actual: point.getRawQueryForTamland(),
    expectThat: {
      local hasNoShardSelectorPlaceholder = std.length(std.findSubstr('%(shardSelector)s', self.actual)) == 0,
      local hasSelectorPlaceholder = std.length(std.findSubstr('%(selector)s', self.actual)) > 0,
      local hasInterpolatedShardFilter = std.length(std.findSubstr('shard!="throttled"', self.actual)) > 0,
      result: hasNoShardSelectorPlaceholder && hasSelectorPlaceholder && hasInterpolatedShardFilter,
      description: 'Expect queryFormatConfig to be interpolated while preserving %(selector)s',
    },
  },

  testRawQueryForTamlandHandlesNumericQueryFormatConfig: {
    local point = resourceSaturationPoint(baseDefinition {
      query: 'test{%(selector)s} / %(maxValue)d',
      queryFormatConfig: { maxValue: 250000 },
      capacityPlanning: { strategy: 'exclude' },
    }),
    actual: point.getRawQueryForTamland(),
    expectThat: {
      local hasSelectorPlaceholder = std.length(std.findSubstr('%(selector)s', self.actual)) > 0,
      local hasInterpolatedNumber = std.length(std.findSubstr('250000', self.actual)) > 0,
      local hasNoMaxValuePlaceholder = std.length(std.findSubstr('%(maxValue)', self.actual)) == 0,
      result: hasSelectorPlaceholder && hasInterpolatedNumber && hasNoMaxValuePlaceholder,
      description: 'Expect numeric queryFormatConfig values to be interpolated correctly',
    },
  },
})
