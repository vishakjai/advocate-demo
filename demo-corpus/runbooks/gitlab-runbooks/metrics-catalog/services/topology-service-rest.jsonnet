local runwayArchetype = import 'service-archetypes/runway-archetype.libsonnet';
local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local histogramApdex = metricsCatalog.histogramApdex;
local rateMetric = metricsCatalog.rateMetric;
local customRateQuery = metricsCatalog.customRateQuery;

metricsCatalog.serviceDefinition(
  runwayArchetype(
    type='topology-rest',
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
      // Priority 1: HTTP Server Performance
      http_server: {
        severity: 's4',
        userImpacting: true,
        serviceAggregation: false,
        team: 'cells_infrastructure',
        featureCategory: 'not_owned',
        regional: true,

        description: |||
          HTTP REST API request performance from OTEL instrumentation.
          Tracks request latency, rate, and errors across all HTTP endpoints.
        |||,

        // Very lax threshold: 60 seconds satisfied, 120 seconds tolerated
        apdex: histogramApdex(
          histogram='topology_service_http_request_duration_seconds_bucket',
          selector={ job: 'topology-service', type: 'topology-rest' },
          satisfiedThreshold=60,
          toleratedThreshold=120,
          metricsFormat='migrating'
        ),

        requestRate: rateMetric(
          counter='topology_service_http_requests_total',
          selector={ job: 'topology-service', type: 'topology-rest' },
          useRecordingRuleRegistry=false,
        ),

        errorRate: rateMetric(
          counter='topology_service_http_requests_total',
          selector={ job: 'topology-service', type: 'topology-rest', code: { re: '5..' } },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['method', 'route', 'code', 'region'],

        monitoringThresholds+: {
          apdexScore: 0.5,  // 50% acceptable for initial deployment
          errorRatio: 0.5,  // 50% error rate acceptable initially
        },
      },

      // Priority 1: HTTP In-Flight Requests
      http_in_flight: {
        severity: 's4',
        userImpacting: false,
        serviceAggregation: false,
        team: 'cells_infrastructure',
        featureCategory: 'not_owned',
        regional: true,

        description: |||
          Number of concurrent HTTP requests currently being processed.
          Helps identify traffic spikes and capacity issues.
        |||,

        requestRate: rateMetric(
          counter='topology_service_http_requests_total',
          selector={ job: 'topology-service', type: 'topology-rest' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['region'],
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
          counter='topology_service_http_requests_total',
          selector={ job: 'topology-service', type: 'topology-rest' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['region', 'instance'],
      },

      // Priority 3: Go Runtime
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
          counter='topology_service_http_requests_total',
          selector={ job: 'topology-service', type: 'topology-rest' },
          useRecordingRuleRegistry=false,
        ),

        significantLabels: ['region', 'instance'],
      },
    },
  }
)
