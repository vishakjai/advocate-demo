local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local template = grafana.template;
local basic = import 'grafana/basic.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local text = grafana.text;
local row = grafana.row;

local cloudflareDatasource = { type: 'prometheus', uid: 'mimir-gitlab-ops' };
local prometheusDatasource = { type: 'prometheus', uid: '$PROMETHEUS_DS' };

local prometheusTarget(expr, legendFormat='__auto', refId='A') = {
  datasource: prometheusDatasource,
  editorMode: 'code',
  expr: expr,
  legendFormat: legendFormat,
  range: true,
  refId: refId,
};

local cloudflareTarget(expr, legendFormat='__auto', refId='A') = {
  datasource: cloudflareDatasource,
  editorMode: 'code',
  expr: expr,
  legendFormat: legendFormat,
  range: true,
  refId: refId,
};

local rateFieldConfig = {
  defaults: {
    color: { fixedColor: 'red', mode: 'fixed' },
    custom: {
      lineInterpolation: 'linear',
      lineWidth: 1,
      pointSize: 5,
      scaleDistribution: { type: 'linear' },
    },
    thresholds: {
      mode: 'absolute',
      steps: [{ color: 'red', value: 80 }],
    },
  },
};


local rateOptions = {
  legend: { displayMode: 'list', placement: 'bottom', showLegend: true },
  tooltip: { mode: 'single', sort: 'none' },
};

basic.dashboard(
  'Rate Limiting: Overview',
  tags=['protected', 'rate-limit', 'cloudflare', 'haproxy', 'workhorse', 'rack-attack', 'application-rate-limiter'],
  time_from='now-12h',
  time_to='now',
  editable=true,
  description='This dashboard is intended to surface rate limiting metrics at all layers of the GitLab stack (Cloudflare, HAProxy, RackAttack, ApplicationRateLimiter, etc).\n\nOwner: Production Engineering::Networking and Incident Management Team',
)
.addTemplate(template.custom(
  'zone',
  'gitlab.com, staging.gitlab.com',
  'gitlab.com',
))
.addPanels([
  // Introduction panel
  text.new(
    mode='markdown',
    content=|||
      # Rate Limiting Overview

      This dashboard shows the rate limiting metrics at each layer of GitLab, beginning with the edge and working it's way down to the application.

      Each section contains links to logs to do further investigation.

      📑 Read more: [Rate Limiting Handbook Page](https://handbook.gitlab.com/handbook/engineering/infrastructure-platforms/rate-limiting/)

      ## Datasources
      - Cloudflare has only one datasource: `Mimir - GitLab Ops`.
      - All other panels use the PROMETHEUS_DS dropdown menu to choose environment between `Mimir - Gitlab Gprd` and `Mimir - Gitlab Gstg`.
    |||
  ) + { gridPos: { x: 0, y: 0, w: 24, h: 8 } },

  //######################
  // Cloudflare section
  //######################
  row.new(title='Cloudflare') + { gridPos: { x: 0, y: 9, w: 24, h: 1 } },

  // Cloudflare info panel - left column
  text.new(
    mode='markdown',
    content=|||
      # Cloudflare

      The edge of our network - applies IP based rate limits and other high level blocks.

      ## Datasource
      - PROMETHEUS_DS: `Mimir - GitLab Ops`
      - Zone: Select between `gitlab.com` and `staging.gitlab.com`

      ## Links

      - 📊 [Cloudflare Dashboard: Rate Limit configuration](https://dash.cloudflare.com/852e9d53d0f8adbd9205389356f2303d/gitlab.com/security/waf/rate-limiting-rules)
      - 📊 [Cloudflare Dashboard: Custom Rules configuration](https://dash.cloudflare.com/852e9d53d0f8adbd9205389356f2303d/gitlab.com/security/waf/custom-rules)
      - 📊 [Cloudflare Dashboard: Firewall Events](https://dash.cloudflare.com/852e9d53d0f8adbd9205389356f2303d/gitlab.com/security/events)

      Rules are managed in [config-mgmt](https://ops.gitlab.net/gitlab-com/gl-infra/config-mgmt/-/blob/main/environments/gprd/cloudflare-rate-limits-waf-and-rules.tf)
    |||
  ) + { gridPos: { x: 0, y: 10, w: 8, h: 12 } },

  // Cloudflare rate limited response rate - middle column top
  panel.timeSeries(
    title='Cloudflare rate limited response rate',
    description='Rate of HTTP 429 (Too Many Requests) responses returned by Cloudflare. Indicates requests blocked at the edge before reaching GitLab infrastructure.',
  ) + {
    interval: '1m',
    datasource: cloudflareDatasource,
    targets: [cloudflareTarget('sum by (status) (rate(cloudflare_zone_requests_status{zone="$zone", status="429"}[$__rate_interval]))')],
    fieldConfig: rateFieldConfig { defaults+: { custom+: { showPoints: 'auto' } } },
    options: rateOptions,
    gridPos: { h: 6, w: 8, x: 8, y: 10 },
  },

  // Cloudflare percentage of rate limited requests - right column top
  panel.timeSeries(
    title='Cloudflare percentage of rate limited requests',
    description='Percentage of requests rate limited by Cloudflare. Calculated as (429 responses / total responses) X 100. Values above 40% may indicate a broader issue.',
  ) + {
    interval: '60s',
    datasource: cloudflareDatasource,
    targets: [cloudflareTarget(
      |||
        (
          sum (rate(cloudflare_zone_requests_status{zone='$zone', status="429"}[$__rate_interval]))
          /
          sum (rate(cloudflare_zone_requests_status{zone='$zone', status!=""}[$__rate_interval]))
        ) * 100
      |||,
      'Percentage of rate limited requests'
    )],
    fieldConfig: rateFieldConfig {
      defaults+: {
        mappings: [{ options: { '40': { index: 0, text: 'WARN 40%' } }, type: 'value' }],
        thresholds+: { steps: [{ color: 'red', value: 40 }] },
        unit: 'percent',
      },
    },
    options: rateOptions,
    gridPos: { h: 6, w: 8, x: 16, y: 10 },
  },

  // Cloudflare ratelimit block events - middle column bottom
  panel.timeSeries(
    title='Cloudflare ratelimit block events',
    description='Rate of firewall events triggered by Cloudflare rate limiting rules. Shows requests blocked by configured rate limit policies.',
  ) + {
    interval: '60s',
    datasource: cloudflareDatasource,
    targets: [cloudflareTarget('sum by (action) (rate(cloudflare_zone_firewall_events_count{zone="$zone", source="ratelimit",action="block"}[$__rate_interval]))')],
    fieldConfig: rateFieldConfig,
    options: rateOptions { legend+: { calcs: [] } },
    gridPos: { h: 6, w: 8, x: 8, y: 16 },
  },

  // Cloudflare events by source - right column bottom
  panel.timeSeries(
    title='Cloudflare events by source',
    description='All Cloudflare firewall events broken down by source (ratelimit, firewall, waf, etc.) and action (block, challenge, log). Provides broader context for edge-level security events.',
  ) + {
    interval: '60s',
    datasource: cloudflareDatasource,
    targets: [cloudflareTarget('sum by (source,action) (rate(cloudflare_zone_firewall_events_count{zone="$zone"}[$__rate_interval]))')],
    fieldConfig: rateFieldConfig { defaults+: { color: { fixedColor: 'red', mode: 'palette-classic' } } },
    options: rateOptions,
    gridPos: { h: 6, w: 8, x: 16, y: 16 },
  },

  //######################
  // HAProxy section
  //######################
  row.new(title='HAProxy') + { gridPos: { h: 1, w: 24, x: 0, y: 32 } },

  // HAProxy info panel - left column
  text.new(
    mode='markdown',
    content=|||
      # HAProxy

      - Provides rate limiting for GitLab Pages and Registry.

      - These metrics are only by `4xx` which could mean rate limited responses, or any other client side error status, such as unauthenticated. It doesn't provide the most value.

      ## Datasource
      - Use the PROMETHEUS_DS dropdown to select between `Mimir - Gitlab Gprd` and `mMimir - Gitlab Gstg`

      ## Links
      - 📊 [HAProxy BigQuery](https://console.cloud.google.com/bigquery?project=gitlab-production&pli=1&ws=!1m4!1m3!3m2!1sgitlab-production!2shaproxy_logs)
    |||
  ) + { gridPos: { h: 9, w: 8, x: 0, y: 33 } },

  // HAProxy 4xx response rate by backend - middle column
  panel.timeSeries(
    title='HAProxy 4xx response rate by backend',
    description="Rate of 4xx client errors across all HAProxy backends. Note: This includes all 4xx errors (401, 403, 404, 429, etc.), not just rate limiting. Use for general error trends. We don't have the granularity to differentiate between 4xx client errors with HAProxy.",
  ) + {
    interval: '1m',
    datasource: prometheusDatasource,
    targets: [prometheusTarget('sum by (backend)(rate(haproxy_backend_http_responses_total{code="4xx"}[$__rate_interval]))')],
    fieldConfig: rateFieldConfig { defaults+: { color: { mode: 'palette-classic' } } },
    options: rateOptions,
    gridPos: { h: 9, w: 8, x: 8, y: 33 },
  },

  // HAProxy 4xx response rate: pages_http, registry - right column
  panel.timeSeries(
    title='HAProxy 4xx response rate: pages_http, registry',
    description='4xx error rate specifically for GitLab Pages and Registry backends, which use HAProxy for rate limiting. Increases may indicate rate limiting or authentication issues.',
  ) + {
    interval: '1m',
    datasource: prometheusDatasource,
    targets: [prometheusTarget('sum by (backend) (rate(haproxy_backend_http_responses_total{code="4xx", backend=~"pages_http|registry"}[$__rate_interval]))')],
    fieldConfig: rateFieldConfig {
      defaults+: {
        color: { fixedColor: 'orange', mode: 'shades' },
        custom+: { lineInterpolation: null },
      },
    },
    options: rateOptions,
    gridPos: { h: 9, w: 8, x: 16, y: 33 },
  },

  //######################
  // Workhorse section
  //######################
  row.new(title='Application::Workhorse Metrics') + { gridPos: { h: 1, w: 24, x: 0, y: 42 } },

  // Workhorse info panel - left column
  text.new(
    mode='markdown',
    content=|||
      # Workhorse

      - HTTP Request Metrics from Workhorse by status.

      - Doesn't show which rate limiter applied the throttle, but does give a signal if the application was doing the throttling.

      ## Datasource
      - Use the PROMETHEUS_DS dropdown to select between `Mimir - Gitlab Gprd` and `mMimir - Gitlab Gstg`

      ## Links
      - 📊 [Workhorse: Rate Limited](https://log.gprd.gitlab.net/app/discover#/view/7b6dc396-5b27-4e86-b150-72b476255faf?_g=())
    |||
  ) + { gridPos: { h: 9, w: 8, x: 0, y: 43 } },

  // Workhorse rate limited response rate - middle column
  panel.timeSeries(
    title='Workhorse rate limited response rate',
    description="Rate of 429 responses from Workhorse. Indicates application-level rate limiting, though doesn't specify which limiter (RackAttack, ApplicationRateLimiter, etc.) triggered it.",
  ) + {
    interval: '1m',
    datasource: prometheusDatasource,
    targets: [prometheusTarget('sum by (code, env)(sli_aggregations:gitlab_workhorse_http_requests_total:rate_5m{code="429"})')],
    fieldConfig: rateFieldConfig { defaults+: { color: { fixedColor: 'red', mode: 'shades' } } },
    options: rateOptions,
    gridPos: { h: 9, w: 8, x: 8, y: 43 },
  },

  // Workhorse response rate by status - right column
  panel.timeSeries(
    title='Workhorse response rate by status',
    description='Overall HTTP response rates from Workhorse broken down by status code (2xx, 3xx, 4xx, 5xx). Provides context for rate limiting within total traffic patterns.',
  ) + {
    interval: '1m',
    datasource: prometheusDatasource,
    targets: [prometheusTarget('sum by (code, env)(sli_aggregations:gitlab_workhorse_http_requests_total:rate_5m)')],
    fieldConfig: rateFieldConfig { defaults+: { color: { fixedColor: 'red', mode: 'palette-classic' } } },
    options: { legend: { displayMode: 'list', placement: 'bottom', showLegend: true } },
    gridPos: { h: 9, w: 8, x: 16, y: 43 },
  },

  //######################
  // RackAttack  section
  //######################
  row.new(title='Application::Rack Attack') + { gridPos: { h: 1, w: 24, x: 0, y: 52 } },

  // RackAttack info panel - top left
  text.new(
    mode='markdown',
    content=|||
      # RackAttack

      These metrics show the RackAttack throttles that have been triggered during the selected timeframe.

      ## Datasource
      - Use the PROMETHEUS_DS dropdown to select between `Mimir - Gitlab Gprd` and `mMimir - Gitlab Gstg`

      ## Links
      - 📊 [RackAttack: Kibana logs](https://log.gprd.gitlab.net/app/discover#/view/0026cc97-6b9a-445a-a364-7197e04053a2?_g=())
        - Use the `json.matched` field to filter by throttle.
      - 📊 [Support Rate Limit Kibana Dashboard](https://log.gprd.gitlab.net/app/r/s/AJDZC)
    |||
  ) + { gridPos: { h: 9, w: 8, x: 0, y: 53 } },

  // RackAttack rate limited response rate - top right
  panel.timeSeries(
    title='RackAttack rate limited response rate',
    description='Rate of RackAttack throttle events by event name and type. Each spike indicates a specific throttle rule was triggered. Cross-reference event names with Kibana logs for details.',
  ) + {
    datasource: prometheusDatasource,
    targets: [prometheusTarget('sum(rate(gitlab_rack_attack_events_total[$__rate_interval])) by (event_name, event_type)')],
    fieldConfig: rateFieldConfig { defaults+: { color: { mode: 'palette-classic' } } },
    options: rateOptions { legend+: { displayMode: 'table', placement: 'right' } },
    gridPos: { h: 9, w: 16, x: 8, y: 53 },
  },

  // RackAttack throttle limits - bottom left
  {
    type: 'stat',
    title: 'RackAttack throttle limits',
    description: 'Configured maximum request counts for each RackAttack throttle rule. These are the thresholds before throttling begins.',
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'text', value: null }] } } },
    options: { colorMode: 'value', justifyMode: 'auto', orientation: 'horizontal', percentChangeColorMode: 'standard', reduceOptions: { calcs: ['lastNotNull'] }, wideLayout: true },
    targets: [{ editorMode: 'code', expr: 'max(gitlab_rack_attack_throttle_limit) by (event_name)', legendFormat: '__auto' }],
    gridPos: { h: 7, w: 12, x: 0, y: 62 },
  },

  // RackAttack throttle period (seconds) - bottom right
  {
    type: 'stat',
    title: 'RackAttack throttle period (seconds)',
    description: 'Time window (in seconds) for each RackAttack throttle rule. Limits are enforced within this rolling time period.',
    fieldConfig: { defaults: { color: { mode: 'thresholds' }, thresholds: { mode: 'absolute', steps: [{ color: 'text', value: null }] } } },
    options: { colorMode: 'value', justifyMode: 'auto', orientation: 'horizontal', percentChangeColorMode: 'standard', reduceOptions: { calcs: ['lastNotNull'] }, wideLayout: true },
    targets: [{ editorMode: 'code', expr: 'max(gitlab_rack_attack_throttle_period_seconds) by (event_name)', legendFormat: '__auto' }],
    gridPos: { h: 7, w: 12, x: 12, y: 62 },
  },

  //##################################
  // ApplicationRateLimiter section
  //##################################
  row.new(title='Application::ApplicationRateLimiter') + { gridPos: { h: 1, w: 24, x: 0, y: 69 } },

  // ApplicationRateLimiter info panel - left column
  text.new(
    mode='markdown',
    content=|||
      # ApplicationRateLimiter

      Intelligent application rate limits.

      ## Datasource
      - Use the PROMETHEUS_DS dropdown to select between `Mimir - Gitlab Gprd` and `mMimir - Gitlab Gstg`

      ## Links
      - 📊 [ApplicationRateLimiter: Kibana Logs](https://log.gprd.gitlab.net/app/discover#/view/2d2cf10e-b22a-4c07-bbda-45bb665c31ee?_g=())
        - Use the `json.env` field to filter by throttle.
    |||
  ) + { gridPos: { h: 9, w: 8, x: 0, y: 70 } },

  // ApplicationRateLimiter rate of throttled requests by key - right column
  panel.timeSeries(
    title='ApplicationRateLimiter rate of throttled requests by key',
    description=|||
      Rate of throttled requests by throttle_key.
      This panel calculates throttled requests using histogram subtraction:
      - Total requests (le="+Inf") minus non-throttled requests (le="1" or "1.0")
      - A request is considered throttled when its utilization ratio exceeds 100%
      Higher values indicate more requests are being blocked by ApplicationRateLimiter.
    |||,
  ) + {
    interval: '1m',
    datasource: prometheusDatasource,
    targets: [
      prometheusTarget('sum by (throttle_key) (rate(gitlab_application_rate_limiter_throttle_utilization_ratio_bucket{env="$environment", le="+Inf"}[1m]))', refId='A') + { hide: true },
      prometheusTarget('sum by (throttle_key) (rate(gitlab_application_rate_limiter_throttle_utilization_ratio_bucket{env="$environment", le=~"1|1\\\\.0"}[1m]))', refId='B') + { hide: true },
      {
        datasource: { name: 'Expression', type: '__expr__', uid: '__expr__' },
        expression: '$A - $B',
        hide: false,
        refId: 'throttle rate:',
        type: 'math',
      },
    ],
    fieldConfig: rateFieldConfig { defaults+: { color: { mode: 'palette-classic' } } },
    options: rateOptions { legend+: { calcs: [], displayMode: 'table', placement: 'right' }, tooltip+: { hideZeros: false } },
    gridPos: { h: 9, w: 16, x: 8, y: 70 },
  },
])
