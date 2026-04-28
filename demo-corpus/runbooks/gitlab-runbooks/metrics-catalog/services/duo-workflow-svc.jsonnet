local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local customRateQuery = metricsCatalog.customRateQuery;
local runwayHelper = import 'service-archetypes/helpers/runway.libsonnet';

local baseSelector = { type: 'duo-workflow-svc' };

metricsCatalog.serviceDefinition(
  runwayArchetype(
    type='duo-workflow-svc',
    team='agent_foundations',
    severity='s2',
    featureCategory='duo_agent_platform',
    apdexScore=0.95,
    errorRatio=0.95,
    // Runway is using stackdriver metrics, these metrics use many buckets in milliseconds
    // To pick an available bucket, we need to look at the source metrics
    // https://dashboards.gitlab.net/goto/GiFs0eTIR?orgId=1
    // Pick a value that is larger than the server SLIs this encapsulates
    apdexSatisfiedThreshold='32989.690295920576',
    externalLoadBalancer=true,
  )
  {
    local runwayLabels = runwayHelper.labels(self),
    local grpcLabels = [
      'grpc_code',
      'grpc_method',
      'grpc_service',
      'grpc_type',
    ],
    local llmLabels = [
      'model_engine',
      'model_name',
      'feature_category',
      'finish_reason',
      'error_type',
    ],
    local metadataLabels = [
      'lsp_version',
      'gitlab_version',
      'client_type',
      'gitlab_realm',
    ],

    serviceLevelIndicators+: {
      server_chat: {
        severity: 's2',
        userImpacting: true,
        featureCategory: 'duo_agent_platform',
        useConfidenceLevelForSLIAlerts: '98%',
        description: |||
          This SLI monitors all Duo Workflow Service GRPC requests for chat flows.
          GRPC failures which are considered to be the "server's fault" are counted as errors.
        |||,

        monitoringThresholds: {
          apdexScore: 0.95,
          errorRatio: 0.99,
        },

        requestRate: rateMetric(
          counter='grpc_server_handled_total',
          selector=baseSelector {
            flow_type: 'chat',
          }
        ),

        errorRate: rateMetric(
          counter='grpc_server_handled_total',
          selector=baseSelector {
            flow_type: 'chat',
            grpc_code: { noneOf: ['OK', 'RESOURCE_EXHAUSTED', 'INVALID_ARGUMENT'] },
          }
        ),

        apdex: histogramApdex(
          histogram='duo_workflow_time_to_first_response_seconds_bucket',
          selector=baseSelector {
            flow_type: 'chat',
            gitlab_realm: 'saas',
          },
          satisfiedThreshold=2.5,
          toleratedThreshold=5,
          metricsFormat='migrating'
        ),

        significantLabels: ['flow_type'] + grpcLabels + runwayLabels + metadataLabels,
      },

      server_foundational: {
        severity: 's2',
        userImpacting: true,
        featureCategory: 'duo_agent_platform',
        useConfidenceLevelForSLIAlerts: '98%',
        description: |||
          This SLI monitors all Duo Workflow Service GRPC requests for foundational flows.
          GRPC failures which are considered to be the "server's fault" are counted as errors.
        |||,

        monitoringThresholds: {
          apdexScore: 0.95,
          errorRatio: 0.95,
        },

        requestRate: rateMetric(
          counter='grpc_server_handled_total',
          selector=baseSelector {
            flow_type: { noneOf: ['chat', 'unknown'] },
          }
        ),

        errorRate: rateMetric(
          counter='grpc_server_handled_total',
          selector=baseSelector {
            flow_type: { noneOf: ['chat', 'unknown'] },
            grpc_code: { noneOf: ['OK', 'RESOURCE_EXHAUSTED', 'INVALID_ARGUMENT'] },
          }
        ),

        apdex: histogramApdex(
          histogram='duo_workflow_time_to_first_response_seconds_bucket',
          selector=baseSelector {
            flow_type: { noneOf: ['chat', 'unknown'] },
            gitlab_realm: 'saas',
          },
          satisfiedThreshold=2.5,
          toleratedThreshold=5,
          metricsFormat='migrating'
        ),

        significantLabels: ['flow_type'] + grpcLabels + runwayLabels + metadataLabels,
      },

      server_unknown: {
        severity: 's2',
        userImpacting: true,
        featureCategory: 'duo_agent_platform',
        useConfidenceLevelForSLIAlerts: '98%',
        description: |||
          This SLI monitors all Duo Workflow Service GRPC requests for unknown flows.
          Unknown flows can be from gRPC endpoints GenerateToken, ListTools or TrackSelfHostedExecuteWorkflow
          as they don't have flow_type. It could also be a faulty ExecuteWorkflow request.
          GRPC failures which are considered to be the "server's fault" are counted as errors.
        |||,

        monitoringThresholds: {
          apdexScore: 0.95,
          errorRatio: 0.95,
        },

        requestRate: rateMetric(
          counter='grpc_server_handled_total',
          selector=baseSelector {
            flow_type: 'unknown',
          }
        ),

        errorRate: rateMetric(
          counter='grpc_server_handled_total',
          selector=baseSelector {
            flow_type: 'unknown',
            grpc_code: { noneOf: ['OK', 'RESOURCE_EXHAUSTED', 'INVALID_ARGUMENT'] },
          }
        ),

        apdex: histogramApdex(
          histogram='duo_workflow_time_to_first_response_seconds_bucket',
          selector=baseSelector {
            flow_type: 'unknown',
            gitlab_realm: 'saas',
          },
          satisfiedThreshold=2.5,
          toleratedThreshold=5,
          metricsFormat='migrating'
        ),

        significantLabels: ['flow_type'] + grpcLabels + runwayLabels + metadataLabels,
      },

      server_invalid: {
        severity: 's3',
        userImpacting: true,
        featureCategory: 'duo_agent_platform',
        useConfidenceLevelForSLIAlerts: '98%',
        description: |||
          This SLI monitors the rate of INVALID_ARGUMENT gRPC responses across all
          Duo Workflow Service flows. While INVALID_ARGUMENT typically indicates a
          client-side error (e.g. malformed requests, missing fields), an abnormal
          spike may signal a broader issue such as a DDoS attack, a broken client
          release, or an incompatible API change. This SLI is excluded from the
          primary error budgets of other server SLIs so it can be tracked
          independently with a lower severity threshold.
        |||,

        monitoringThresholds: {
          errorRatio: 0.95,
        },

        requestRate: rateMetric(
          counter='grpc_server_handled_total',
          selector=baseSelector
        ),

        errorRate: rateMetric(
          counter='grpc_server_handled_total',
          selector=baseSelector {
            grpc_code: 'INVALID_ARGUMENT',
          }
        ),

        significantLabels: ['flow_type'] + grpcLabels + runwayLabels + metadataLabels,
      },

      tool_use: {
        severity: 's2',
        userImpacting: true,
        featureCategory: 'duo_agent_platform',
        useConfidenceLevelForSLIAlerts: '98%',
        description: |||
          This SLI monitors tool failure rates within agent platform sessions. Tool failures are
          non-fatal events that don't immediately terminate sessions since agents can retry or use
          alternative approaches, but increasing failure rates serve as early warning indicators of
          potential system issues.
        |||,
        monitoringThresholds: {
          errorRatio: 0.95,
        },

        requestRate: rateMetric(
          counter='duo_workflow_tool_call_seconds_count',
          selector=baseSelector
        ),

        errorRate: rateMetric(
          counter='agent_platform_tool_failure_total',
          selector=baseSelector
        ),

        significantLabels: ['tool_name', 'flow_type'] + runwayLabels + metadataLabels,
      },

      llm: {
        severity: 's2',
        userImpacting: true,
        featureCategory: 'duo_agent_platform',
        useConfidenceLevelForSLIAlerts: '98%',
        description: |||
          This SLI monitors all Duo Workflow LLM requests.
          Failure indicates that a root cause analysis for error_type is required.
        |||,
        monitoringThresholds: {
          errorRatio: 0.99,
        },

        requestRate: rateMetric(
          counter='model_inferences_total',
          selector=baseSelector
        ),

        errorRate: rateMetric(
          counter='model_inferences_total',
          selector=baseSelector { 'error': 'yes' }
        ),

        significantLabels: llmLabels + runwayLabels + metadataLabels,
      },

      llm_finish_reason: {
        severity: 's4',
        userImpacting: true,
        featureCategory: 'duo_agent_platform',
        useConfidenceLevelForSLIAlerts: '98%',
        description: |||
          This SLI monitors Duo Workflow LLM requests' finish/stop reason.
          Failure indicates that a root cause analysis for unexpected stop reason is required.
        |||,
        monitoringThresholds: {
          errorRatio: 0.95,
        },

        requestRate: rateMetric(
          counter='model_inferences_total',
          selector=baseSelector
        ),

        errorRate: rateMetric(
          counter='model_inferences_total',
          selector=baseSelector { finish_reason: { oneOf: ['length', 'max_tokens', 'model_context_window_exceeded'] } }
        ),
        significantLabels: llmLabels + runwayLabels + metadataLabels,
      },

      checkpoint_errors: {
        severity: 's2',
        userImpacting: true,
        featureCategory: 'duo_agent_platform',
        useConfidenceLevelForSLIAlerts: '98%',
        description: |||
          This SLI monitors checkpoint errors in Duo Workflow Service.
          Tracks checkpoint operation failures that could impact workflow persistence.
        |||,

        monitoringThresholds: {
          errorRatio: 0.95,
        },

        requestRate: rateMetric(
          counter='duo_workflow_checkpoint_total',
          selector=baseSelector
        ),

        errorRate: rateMetric(
          counter='duo_workflow_checkpoint_total',
          // Catch both 4xx and 5xx errors
          selector=baseSelector {
            status_code: { re: '[45]..' },
          }
        ),

        significantLabels: ['status_code'] + runwayLabels + metadataLabels,
      },
    },
  },
)
