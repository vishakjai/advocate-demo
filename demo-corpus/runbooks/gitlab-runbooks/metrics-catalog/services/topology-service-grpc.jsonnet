local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local customRateQuery = metricsCatalog.customRateQuery;

metricsCatalog.serviceDefinition(
  runwayArchetype(
    type='topology-grpc',
    team='cells_infrastructure',
    regional=true,
    // When using stackdriver_cloud_run_revision_run_googleapis_com_request_latencies_bucket as source metrics request latencies are put into specific
    // buckets this number is chosen to align with the closest desirable bucket see buckets here https://dashboards.gitlab.net/goto/vnxXtRZHg?orgId=1
    apdexSatisfiedThreshold='74.00249944258171',
    apdexScore=0.9995,
    errorRatio=0.9995,
    severity='s3',
    tags=['golang'],
    trafficCessationAlertConfig=false,
  )
  {
    serviceLevelIndicators+: {
      // Priority 1: gRPC Server Performance
      grpc_server: {
        severity: 's4',
        userImpacting: true,
        serviceAggregation: false,
        team: 'cells_infrastructure',
        featureCategory: 'not_owned',
        regional: true,

        description: |||
          gRPC server request performance metrics from OTEL instrumentation.
          Tracks request latency, rate, and errors across all gRPC methods.
        |||,

        // Very lax threshold: 100 seconds satisfied, 200 seconds tolerated
        apdex: histogramApdex(
          histogram='rpc_server_duration_milliseconds_bucket',
          selector={ job: 'topology-service', type: 'topology-grpc' },
          satisfiedThreshold=100000,  // 100s in milliseconds
          toleratedThreshold=200000,  // 200s in milliseconds
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='rpc_server_duration_milliseconds_count',
          selector={ job: 'topology-service', type: 'topology-grpc' },
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='rpc_server_duration_milliseconds_count',
          selector={ job: 'topology-service', type: 'topology-grpc', grpc_status_code: { noneOf: ['OK'] } },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['rpc_method', 'rpc_service', 'region'],

        monitoringThresholds+: {
          apdexScore: 0.5,  // 50% acceptable for initial deployment
          errorRatio: 0.5,  // 50% error rate acceptable initially
        },
      },

      // Priority 2: Process Resources
      process_resources: {
        severity: 's4',
        userImpacting: false,
        serviceAggregation: false,
        team: 'cells_infrastructure',
        featureCategory: 'not_owned',
        regional: true,

        description: |||
          Process-level resource utilization: CPU, memory, file descriptors.
          Monitors system resource consumption of the topology service instances.
        |||,

        requestRate: rateMetric(
          counter='rpc_server_duration_milliseconds_count',
          selector={ job: 'topology-service', type: 'topology-grpc' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['region', 'instance'],
      },

      // Priority 3: RBAC Authentication
      auth_requests: {
        severity: 's4',
        userImpacting: true,
        serviceAggregation: false,
        team: 'cells_infrastructure',
        featureCategory: 'not_owned',
        regional: true,

        description: |||
          RBAC mTLS authentication metrics for the Topology Service.
          Tracks authentication success/failure rates and authentication
          duration for all gRPC methods.
          Note: auth_request_duration_seconds histogram may have limited data
          until traffic ramps up — apdex thresholds will be tuned after real data.
        |||,

        apdex: histogramApdex(
          histogram='auth_request_duration_seconds_bucket',
          selector={ job: 'topology-service', type: 'topology-grpc' },
          satisfiedThreshold=1,  // 1 second — auth should be sub-second
          toleratedThreshold=5,  // 5 seconds — to be tuned after real data
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='auth_requests_total',
          selector={ job: 'topology-service', type: 'topology-grpc' },
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='auth_requests_total',
          selector={ job: 'topology-service', type: 'topology-grpc', status: 'failure' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['rpc_method', 'rpc_service', 'reason', 'region'],

        monitoringThresholds+: {
          apdexScore: 0.5,  // 50% acceptable for initial deployment — tune after data
          errorRatio: 0.5,  // 50% error rate acceptable initially — tune after data
        },
      },

      // Priority 4: Go Runtime
      go_runtime: {
        severity: 's4',
        userImpacting: false,
        serviceAggregation: false,
        team: 'cells_infrastructure',
        featureCategory: 'not_owned',
        regional: true,

        description: |||
          Go runtime metrics: goroutines, garbage collection, memory statistics.
          Monitors Go-specific runtime behavior and performance characteristics.
        |||,

        requestRate: rateMetric(
          counter='rpc_server_duration_milliseconds_count',
          selector={ job: 'topology-service', type: 'topology-grpc' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['region', 'instance'],
      },
    },
  }
)
