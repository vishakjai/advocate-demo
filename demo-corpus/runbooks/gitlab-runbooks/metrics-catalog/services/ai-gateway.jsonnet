local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local histogramApdex = metricsCatalog.histogramApdex;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';
local runwayHelper = import 'service-archetypes/helpers/runway.libsonnet';
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local serviceLevelIndicatorDefinition = import 'servicemetrics/service_level_indicator_definition.libsonnet';

local baseSelector = { type: 'ai-gateway' };
local serverSelector = baseSelector {
  handler: {
    noneOf:
      [
        '/v2/code/completions',
        '/v2/completions',
        '/v2/code/generations',
        '/v(1|2)/chat/.*',
        '/v1/x-ray/libraries',
      ],
  },
};
local serverCodeCompletionsSelector = baseSelector {
  handler: { oneOf: ['/v2/code/completions', '/v2/completions'] },
};
local serverCodeGenerationsSelector = baseSelector {
  handler: { oneOf: ['/v2/code/generations', '/v3/code/completions', '/v4/code/suggestions'] },
};
local serverChatSelector = baseSelector { handler: { re: '/v(1|2)/chat/.*' } };
local serverXRaySelector = baseSelector { handler: '/v1/x-ray/libraries' };

metricsCatalog.serviceDefinition(
  // Default Runway SLIs
  runwayArchetype(
    type='ai-gateway',
    team='ai_coding',
    apdexScore=0.95,
    errorRatio=0.98,  // Get product to decide whether to keep the less strict SLO https://gitlab.com/gitlab-com/gl-infra/production-engineering/-/issues/26373
    featureCategory='code_suggestions',
    // Runway is using stackdriver metrics, these metrics use many buckets in milliseconds
    // To pick an available bucket, we need to look at the source metrics
    // https://dashboards.gitlab.net/goto/GiFs0eTIR?orgId=1
    // Pick a value that is larger than the server SLIs this encapsulates
    apdexSatisfiedThreshold='32989.690295920576',
    severity='s2',
    regional=true,
    customToolingLinks=[
      toolingLinks.kibana(
        title='MLOps',
        index='mlops',
        includeMatchersForPrometheusSelector=false,
        matches={ 'json.jsonPayload.project_id': 'gitlab-runway-production' }
      ),
    ],
    // The traffic cessation config here has a `location=""` selector to
    // avoid triggering this alert in Thanos. In thanos the `region` label is incorrect.
    // The `location` label contains the correct value in Thanos. However, Mimir does not
    // have this label.
    // This can be removed in https://gitlab.com/gitlab-com/gl-infra/scalability/-/issues/3398
    trafficCessationAlertConfig={ regional_component: { region: { re: 'us-.*' }, location: '' } },
  )
  // Custom AI Gateway SLIs
  {
    // Labels set by
    // https://pypi.org/project/prometheus-fastapi-instrumentator
    local runwayLabels = runwayHelper.labels(self),
    local commonServerLabels = [
      'status',
      'handler',
      'method',
    ] + runwayLabels,

    serviceLevelIndicators+: {
      server: {
        severity: 's4',
        trafficCessationAlertConfig: false,
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_coding',
        featureCategory: 'code_suggestions',
        description: |||
          FastAPI server for AI Gateway.
        |||,

        apdex: histogramApdex(
          histogram='http_request_duration_seconds_bucket',
          selector=serverSelector { status: { noneOf: ['4xx', '5xx'] } },
          satisfiedThreshold=5,
          toleratedThreshold=10,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverSelector,
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverSelector { status: '5xx' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: commonServerLabels,

        toolingLinks: [
          toolingLinks.kibana(
            title='FastAPI Server',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            matches={ 'json.jsonPayload.logger': 'api.access' }
          ),
        ],
      },
      server_code_completions: {
        severity: 's2',
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_coding',
        featureCategory: 'code_suggestions',
        trafficCessationAlertConfig: false,
        description: |||
          FastAPI server for AI Gateway - code completions.
        |||,


        monitoringThresholds+: {
          apdexScore: 0.95,
        },

        apdex: histogramApdex(
          histogram='http_request_duration_seconds_bucket',
          selector=serverCodeCompletionsSelector { status: { noneOf: ['4xx', '5xx'] } },
          satisfiedThreshold=1,
          toleratedThreshold=10,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverCodeCompletionsSelector,
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverCodeCompletionsSelector { status: '5xx' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: commonServerLabels,

        toolingLinks: [
          toolingLinks.kibana(
            title='FastAPI Server - code completions',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            matches={ 'json.jsonPayload.logger': 'api.access', 'json.jsonPayload.path': '/v2/code/completions' }
          ),
        ],
      },
      server_code_generations: {
        severity: 's2',
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_coding',
        featureCategory: 'code_suggestions',
        trafficCessationAlertConfig: false,
        description: |||
          FastAPI server for AI Gateway - code generations.
        |||,

        apdex: histogramApdex(
          histogram='http_request_duration_seconds_bucket',
          selector=serverCodeGenerationsSelector { status: { noneOf: ['4xx', '5xx'] } },
          satisfiedThreshold=30,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverCodeGenerationsSelector,
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverCodeGenerationsSelector { status: '5xx' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: commonServerLabels,

        toolingLinks: [
          toolingLinks.kibana(
            title='FastAPI Server - code generations',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            matches={ 'json.jsonPayload.logger': 'api.access', 'json.jsonPayload.path': '/v2/code/generations' }
          ),
        ],
      },
      server_chat: {
        severity: 's4',
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_framework',
        featureCategory: 'duo_chat',
        trafficCessationAlertConfig: false,
        description: |||
          FastAPI server for AI Gateway - chat.
        |||,

        apdex: histogramApdex(
          histogram='http_request_duration_seconds_bucket',
          selector=serverChatSelector { status: { noneOf: ['4xx', '5xx'] } },
          satisfiedThreshold=30,
          toleratedThreshold=60,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverChatSelector,
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverChatSelector { status: '5xx' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: commonServerLabels,

        toolingLinks: [
          toolingLinks.kibana(
            title='FastAPI Server - chat',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            matches={ 'json.jsonPayload.logger': 'api.access', 'json.jsonPayload.path': '/v1/chat/agent' }
          ),
        ],
      },
      server_x_ray: {
        severity: 's4',
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_coding',
        featureCategory: 'code_suggestions',
        trafficCessationAlertConfig: false,
        description: |||
          FastAPI server for AI Gateway - X-Ray.
        |||,

        apdex: histogramApdex(
          histogram='http_request_duration_seconds_bucket',
          selector=serverXRaySelector { status: { noneOf: ['4xx', '5xx'] } },
          satisfiedThreshold=30,
          toleratedThreshold=60,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverXRaySelector,
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverXRaySelector { status: '5xx' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: commonServerLabels,

        toolingLinks: [
          toolingLinks.kibana(
            title='FastAPI Server - X-Ray',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            matches={ 'json.jsonPayload.logger': 'api.access', 'json.jsonPayload.path': '/v1/x-ray/libraries' }
          ),
        ],
      },
      inference_anthropic: {
        severity: 's3',
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_framework',
        featureCategory: serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics,
        trafficCessationAlertConfig: false,
        description: |||
          Inferences to the anthropic model used by the AI-gateway.

          Apdex applies to non-streaming inferences, they are considered fast enough
          when the request took less than 30s. Errors don't count toward apdex

          A failure means an inference threw an error, for example when the model is
          not available.
        |||,

        apdex: histogramApdex(
          histogram='inference_request_duration_seconds_bucket',
          selector=baseSelector { 'error': 'no', streaming: 'no', model_engine: { oneOf: ['anthropic', 'anthropic-chat'] } },
          satisfiedThreshold=30,
          toleratedThreshold=60,
          metricsFormat='migrating'
        ),

        errorRate: rateMetric(counter='model_inferences_total', selector=baseSelector { model_engine: { oneOf: ['anthropic', 'anthropic-chat'] }, 'error': 'yes' }),

        requestRate: rateMetric(
          counter='model_inferences_total',
          selector=baseSelector { model_engine: { oneOf: ['anthropic', 'anthropic-chat'] } },
        ),

        significantLabels: ['model_name', 'feature_category'] + runwayLabels,
        useConfidenceLevelForSLIAlerts: '98%',

        monitoringThresholds+: {
          apdexScore: 0.95,
          errorRatio: 0.99,
        },

        toolingLinks: [
          toolingLinks.kibana(
            title='Model Inference',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            filters=[matching.matchInFilter('json.jsonPayload.model_engine', ['anthropic', 'anthropic-chat'])],
          ),
        ],
      },
      inference_vertex: {
        severity: 's2',
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_coding',
        featureCategory: serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics,
        trafficCessationAlertConfig: false,
        description: |||
          Inferences to the vertex-ai engines used by the AI-gateway.

          Apdex applies to non-streaming inferences, they are considered fast enough
          when the request took less than 2s. Errors don't count toward apdex

          A failure means an inference threw an error, for example when the model is
          not available.
        |||,

        apdex: histogramApdex(
          histogram='inference_request_duration_seconds_bucket',
          selector=baseSelector { 'error': 'no', streaming: 'no', model_engine: 'vertex-ai' },
          satisfiedThreshold=2.5,
          toleratedThreshold=5,
          metricsFormat='migrating'
        ),

        errorRate: rateMetric(counter='model_inferences_total', selector=baseSelector { model_engine: 'vertex-ai', 'error': 'yes' }),

        requestRate: rateMetric(
          counter='model_inferences_total',
          selector=baseSelector { model_engine: 'vertex-ai' },
        ),

        significantLabels: ['model_name', 'feature_category'] + runwayLabels,
        useConfidenceLevelForSLIAlerts: '98%',

        toolingLinks: [
          toolingLinks.kibana(
            title='Model Inference',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            filters=[matching.existsFilter('json.jsonPayload.model_engine: vertex-ai')],
          ),
        ],
      },
      inference_fireworks: {
        severity: 's2',
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_coding',
        featureCategory: serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics,
        trafficCessationAlertConfig: false,
        description: |||
          Inferences to the fireworks_ai models used by the AI-gateway.

          Apdex applies to non-streaming inferences, they are considered fast enough
          when the request took less than 30s. Errors don't count toward apdex

          A failure means an inference threw an error, for example when the model is
          not available.
        |||,

        apdex: histogramApdex(
          histogram='inference_request_duration_seconds_bucket',
          selector=baseSelector { 'error': 'no', streaming: 'no', model_engine: 'fireworks_ai' },
          satisfiedThreshold=2.5,
          toleratedThreshold=5,
          metricsFormat='migrating'
        ),

        errorRate: rateMetric(counter='model_inferences_total', selector=baseSelector { model_engine: 'fireworks_ai', 'error': 'yes' }),

        requestRate: rateMetric(
          counter='model_inferences_total',
          selector=baseSelector { model_engine: 'fireworks_ai' },
        ),

        significantLabels: ['model_name', 'feature_category', 'region'] + runwayLabels,
        useConfidenceLevelForSLIAlerts: '98%',

        toolingLinks: [
          toolingLinks.kibana(
            title='Model Inference',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            filters=[matching.existsFilter('json.jsonPayload.model_engine: fireworks_ai')],
          ),
        ],
      },

      inference_other: {
        severity: 's4',  // Currently not triggering alerts as we don't yet have a baseline
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_coding',
        featureCategory: serviceLevelIndicatorDefinition.featureCategoryFromSourceMetrics,
        trafficCessationAlertConfig: false,
        description: |||
          Inferences to model providers other than Vertex or Anthropic.

          Apdex applies to non-streaming inferences, they are considered fast enough
          when the request took less than 2s. Errors don't count toward apdex

          A failure means an inference threw an error, for example when the model is
          not available.
        |||,

        apdex: histogramApdex(
          histogram='inference_request_duration_seconds_bucket',
          selector=baseSelector { 'error': 'no', streaming: 'no', model_engine: { noneOf: ['vertex-ai', 'anthropic', 'anthropic-chat', 'fireworks_ai'] } },
          satisfiedThreshold=30,
          metricsFormat='migrating'
        ),

        errorRate: rateMetric(counter='model_inferences_total', selector=baseSelector { model_engine: { noneOf: ['vertex-ai', 'anthropic', 'anthropic-chat', 'fireworks_ai'] }, 'error': 'yes' }),

        requestRate: rateMetric(
          counter='model_inferences_total',
          selector=baseSelector { model_engine: { noneOf: ['vertex-ai', 'anthropic', 'anthropic-chat', 'fireworks_ai'] } },
        ),

        significantLabels: ['model_engine', 'model_name', 'feature_category'] + runwayLabels,
        useConfidenceLevelForSLIAlerts: '98%',

        toolingLinks: [
          toolingLinks.kibana(
            title='Model Inference',
            index='mlops',
            includeMatchersForPrometheusSelector=false,
            filters=[matching.existsFilter('json.jsonPayload.model_engine: vertex-ai')],
          ),
        ],
      },

      waf: {
        local hostSelector = { zone: 'gitlab.com', host: { re: 'codesuggestions.gitlab.com.*' } },
        severity: 's4',
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_coding',
        featureCategory: 'code_suggestions',
        description: |||
          Cloudflare WAF and rate limit rules for codesuggestions.gitlab.com host.
        |||,
        staticLabels: {
          env: 'ops',
        },

        requestRate: rateMetric(
          counter='cloudflare_zone_requests_status_country_host',
          selector=hostSelector,
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='cloudflare_zone_requests_status_country_host',
          selector=hostSelector {
            status: { re: '^5.*' },
          },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['status'],

        toolingLinks: [
          toolingLinks.cloudflare(host='codesuggestions.gitlab.com'),
          toolingLinks.grafana(title='CloudFlare Overview', dashboardUid='cloudflare-main/cloudflare-overview'),
        ],
      },

      client_errors: {
        severity: 's4',
        trafficCessationAlertConfig: false,
        userImpacting: true,
        serviceAggregation: false,
        team: 'ai_framework',
        featureCategory: 'not_owned',
        experimental: true,
        description: |||
          4xx errors for the AI-gateway, these are regular clientside errors, but a significant
          increase in the could indicate a problem with the clients that we control.

          More information available on the different 4xx status codes and their causes in the Runbooks: https://runbooks.gitlab.com/duo/triage/
        |||,
        requestRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverSelector,
        ),

        significantLabels: commonServerLabels,

        errorRate: rateMetric(
          counter='http_request_duration_seconds_count',
          selector=serverSelector { status: '4xx' },
        ),
      },
    },
    capacityPlanning+: {
      components: [
        {
          name: 'gcp_quota_limit_vertex_ai',
          parameters: {
            ignore_outliers: [
              {
                // https://gitlab.com/gitlab-com/gl-infra/production/-/issues/19616
                start: '2025-04-03',
                end: '2025-05-07',
              },
            ],
          },
        },
      ],
    },
  }
)
