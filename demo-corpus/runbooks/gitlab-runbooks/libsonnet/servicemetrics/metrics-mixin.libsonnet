local metricLabelsSelectorsMixin(
  selector,
  metricNames,
  labels=std.objectFields(selector)
      ) =
  {
    metricNames: metricNames,
    // Only support reflection on hash selectors
    [if std.isObject(selector) then 'supportsReflection']():: {
      // Returns a list of metrics and the labels that they use
      getMetricNamesAndLabels()::
        {
          [metric]: std.set(labels)
          for metric in metricNames
        },

      getMetricNamesAndSelectors()::
        {
          [metric]: selector
          for metric in metricNames
        },
    },
  };

{
  metricLabelsSelectorsMixin:: metricLabelsSelectorsMixin,
}
