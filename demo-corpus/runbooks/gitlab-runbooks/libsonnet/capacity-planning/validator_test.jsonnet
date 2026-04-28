local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';
local validator = import 'utils/validator.libsonnet';
local capacityPlanningValidator = validator.new(import 'validator.libsonnet');


test.suite({
  testWithoutOptionalFields: {
    actual: capacityPlanningValidator.isValid({ capacityPlanning: {} }),
    expect: true,
  },
  testInvalidStrategy: {
    local obj = {
      capacityPlanning: {
        strategy: 'YOLO',
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: ['field capacityPlanning.strategy: value not in valid set: ["exclude", "quantile95_1h", "quantile95_1w", "quantile99_1h", "quantile99_1w"] or null'],
  },
  testValidStrategies: {
    local strategies = [
      'exclude',
      'quantile95_1h',
      'quantile95_1w',
      'quantile99_1h',
      'quantile99_1w',
    ],
    local values = std.map(
      function(strategy)
        { capacityPlanning: { strategy: strategy } },
      strategies
    ),
    actual: std.all(
      std.map(
        function(obj)
          capacityPlanningValidator.isValid(obj),
        values
      )
    ),
    expect: true,
  },
  testInvalidForecastDays: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        forecast_days: -1,
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: ['field capacityPlanning.forecast_days: Number should be >= 0 or null'],
  },
  testValidForecastDays: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        forecast_days: 90,
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: [],
  },
  testInvalidHistoricalDays: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        historical_days: -1,
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: ['field capacityPlanning.historical_days: Number should be >= 0 or null'],
  },
  testValidHistoricalDays: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        historical_days: 360,
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: [],
  },
  testInvalidChangepointsCount: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        changepoints_count: -1,
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: ['field capacityPlanning.changepoints_count: Number should be >= 0 or null'],
  },
  testValidChangepointsCount: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        changepoints_count: 10,
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: [],
  },
  testInvalidSaturationDimensionsKeepAggregate: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        saturation_dimensions_keep_aggregate: 'y',
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: ['field capacityPlanning.saturation_dimensions_keep_aggregate: expected an boolean or null'],
  },
  testValidSaturationDimensionsKeepAggregate: {
    actual: std.all(
      std.map(
        function(obj)
          capacityPlanningValidator.isValid(obj),
        [
          { capacityPlanning: { strategy: 'exclude', saturation_dimensions_keep_aggregate: true } },
          { capacityPlanning: { strategy: 'exclude', saturation_dimensions_keep_aggregate: false } },
        ]
      )
    ),
    expect: true,
  },
  testInvalidSaturationDimensions: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        saturation_dimensions: [
          'shard="ok"',
          { notok: 'shard="ok"' },
          666,
        ],
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: ['field capacityPlanning.saturation_dimensions: expected an array[object[optional(label): string, selector: string]] or null'],
  },
  testValidSaturationDimensions: {
    local obj = {
      capacityPlanning: {
        strategy: 'exclude',
        saturation_dimensions: [
          { selector: 'region="us-east-1"' },
          { selector: 'deployment="prometheus"' },
          { selector: 'shard!="asdf|lkjh|123456"', label: 'shard=weirdos' },
        ],
      },
    },
    actual: capacityPlanningValidator._validationMessages(obj),
    expect: [],
  },
})
