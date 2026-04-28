{
  makeDurationQuery(eventName):: |||
    SELECT
      date_trunc('week', collector_tstamp) as time,
      round(quantileExact(0.9)(duration)) as p90,
      round(quantileExact(0.8)(duration)) as p80,
      round(quantileExact(0.5)(duration)) as p50,
      round(quantileExact(0.3)(duration)) as p30,
      round(avg(duration)) as avg
    FROM
      (
        SELECT
          collector_tstamp,
          visitParamExtractFloat(custom_event_props, 'value') as duration
        FROM
          default.events
        WHERE
          app_id = '$app_id'
          AND custom_event_name = 'Custom %s'
          AND collector_tstamp >= date_trunc('week', date_add(WEEK, -14, now()))
      )
    GROUP BY time
    ORDER BY time ASC
  ||| % eventName,

  makeDurationByStepQuery(eventName):: |||
    SELECT
      date_trunc('week', collector_tstamp) as time,
      key,
      round(quantileExact(0.9)(duration)) as p90,
      round(quantileExact(0.8)(duration)) as p80,
      round(quantileExact(0.5)(duration)) as p50,
      round(quantileExact(0.3)(duration)) as p30,
      round(avg(duration)) as avg
    FROM
      (
        SELECT
          collector_tstamp,
          key,
          JSONExtractFloat(COALESCE(JSONExtractString(custom_event_props, 'extras'), '{}'), key) as duration
        FROM
          default.events
        ARRAY JOIN JSONExtractKeys(COALESCE(JSONExtractString(custom_event_props, 'extras'), '{}')) as key
        WHERE
          app_id = '$app_id'
          AND custom_event_name = 'Custom %s'
          AND collector_tstamp >= date_trunc('week', date_add(WEEK, -14, now()))
          AND JSONExtractFloat(COALESCE(JSONExtractString(custom_event_props, 'extras'), '{}'), key) > 0
          AND key != 'gitlab_sha'
          AND NOT startsWith(key, '_')
      )
    GROUP BY time, key
    ORDER BY time ASC
  ||| % eventName,

  makeDurationPanel(query, title='Duration', gridPos={ h: 8, w: 12, x: 0, y: 2 }):: {
    datasource: 'GitLab Development Kit ClickHouse',
    fieldConfig: {
      defaults: {
        color: { mode: 'palette-classic' },
        custom: {
          axisBorderShow: false,
          axisCenteredZero: false,
          axisColorMode: 'text',
          axisLabel: '',
          axisPlacement: 'auto',
          barAlignment: 0,
          barWidthFactor: 0.6,
          drawStyle: 'line',
          fillOpacity: 0,
          gradientMode: 'none',
          hideFrom: { legend: false, tooltip: false, viz: false },
          insertNulls: false,
          lineInterpolation: 'linear',
          lineWidth: 1,
          pointSize: 5,
          scaleDistribution: { type: 'linear' },
          showPoints: 'auto',
          spanNulls: false,
          stacking: { group: 'A', mode: 'none' },
          thresholdsStyle: { mode: 'off' },
        },
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'green' },
            { color: 'red', value: 80 },
          ],
        },
        unit: 's',
      },
      overrides: [],
    },
    gridPos: gridPos,
    options: {
      legend: {
        calcs: [],
        displayMode: 'list',
        placement: 'bottom',
        showLegend: true,
      },
      tooltip: {
        hideZeros: false,
        mode: 'multi',
        sort: 'none',
      },
    },
    pluginVersion: '11.6.0-pre',
    targets: [{
      datasource: 'GitLab Development Kit ClickHouse',
      editorType: 'sql',
      format: 0,
      meta: {
        builderOptions: {
          columns: [],
          database: '',
          limit: 1000,
          mode: 'list',
          queryType: 'table',
          table: '',
        },
      },
      pluginVersion: '4.8.2',
      queryType: 'timeseries',
      rawSql: query,
      refId: 'A',
    }],
    title: title,
    type: 'timeseries',
  },

  makeSuccessRatePanel(query, title='Success rate', gridPos={ h: 8, w: 12, x: 12, y: 2 }):: {
    datasource: 'GitLab Development Kit ClickHouse',
    fieldConfig: {
      defaults: {
        color: { mode: 'thresholds' },
        custom: {
          axisBorderShow: false,
          axisCenteredZero: false,
          axisColorMode: 'text',
          axisLabel: '',
          axisPlacement: 'auto',
          fillOpacity: 80,
          gradientMode: 'none',
          hideFrom: { legend: false, tooltip: false, viz: false },
          lineWidth: 1,
          scaleDistribution: { type: 'linear' },
          thresholdsStyle: { mode: 'line' },
        },
        displayName: 'Success rate',
        mappings: [],
        thresholds: {
          mode: 'absolute',
          steps: [
            { color: 'red', value: 0 },
            { color: 'yellow', value: 0.6 },
            { color: 'green', value: 0.8 },
          ],
        },
        unit: 'percentunit',
      },
      overrides: [],
    },
    gridPos: gridPos,
    options: {
      barRadius: 0,
      barWidth: 0.97,
      fullHighlight: false,
      groupWidth: 0.7,
      legend: {
        calcs: [],
        displayMode: 'list',
        placement: 'bottom',
        showLegend: true,
      },
      orientation: 'auto',
      showValue: 'auto',
      stacking: 'none',
      tooltip: {
        hideZeros: false,
        mode: 'multi',
        sort: 'none',
      },
      xTickLabelRotation: 0,
      xTickLabelSpacing: 0,
    },
    pluginVersion: '11.6.0-pre',
    targets: [{
      datasource: 'GitLab Development Kit ClickHouse',
      editorType: 'sql',
      format: 0,
      meta: {
        builderOptions: {
          columns: [],
          database: '',
          limit: 1000,
          mode: 'list',
          queryType: 'table',
          table: '',
        },
      },
      pluginVersion: '4.8.2',
      queryType: 'timeseries',
      rawSql: query,
      refId: 'A',
    }],
    title: title,
    type: 'barchart',
  },
}
