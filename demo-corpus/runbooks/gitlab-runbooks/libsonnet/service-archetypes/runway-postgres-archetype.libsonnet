local metricsCatalog = import 'servicemetrics/metrics.libsonnet';
local rateMetric = metricsCatalog.rateMetric;
local toolingLinks = import 'toolinglinks/toolinglinks.libsonnet';

function(
  type,
  descriptiveName,
  featureCategory='not_owned',
  regional=false,
  userImpacting=false,
  severity='s4',
)
  local baseSelector = { type: type };
  {
    type: type,
    tier: 'db',
    tenants: ['runway'],
    tags: ['runway-managed-postgres'],

    monitoringThresholds: {
      apdexScore: 0.999,
      errorRatio: 0.999,
    },

    regional: regional,

    provisioning: {
      runway: true,
      vms: false,
      kubernetes: false,
    },

    serviceIsStageless: true,

    serviceLevelIndicators: {
      transactions_primary: {
        userImpacting: userImpacting,

        severity: severity,

        requestRate: rateMetric(
          counter='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_transaction_count',
          selector=baseSelector
        ),

        errorRate: rateMetric(
          counter='stackdriver_cloudsql_database_cloudsql_googleapis_com_database_postgresql_transaction_count',
          selector=baseSelector { transaction_type: 'rollback' }
        ),

        significantLabels: ['transaction_type'],

        toolingLinks: [
          toolingLinks.cloudSQL(type, 'gitlab-runway-production'),
        ],
      },
    },

    skippedMaturityCriteria: {
      'Structured logs available in Kibana': 'Runway structured logs are temporarily available in Stackdriver',
      'Service exists in the dependency graph': 'No service currently depends on Postgres database, which is under development',
    },
  }
