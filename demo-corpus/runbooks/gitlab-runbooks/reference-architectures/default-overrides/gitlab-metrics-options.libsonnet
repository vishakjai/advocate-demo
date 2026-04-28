local gitalyHelper = import 'service-archetypes/helpers/gitaly.libsonnet';

// For more information on how to configure options, consult
// https://gitlab.com/gitlab-com/runbooks/-/blob/master/reference-architectures/README.md.
{
  elasticacheMonitoring: false,
  minimumSamplesForMonitoring: 3600,
  minimumOpsRateForMonitoring: null,
  rdsMonitoring: false,
  rdsInstanceRAMBytes: null,
  rdsMaxAllocatedStorageGB: null,

  // set useGitlabSSHD to true to enable monitoring of gitlab-sshd instead of
  // the legacy gitlab-shell approach.
  useGitlabSSHD: false,

  // By default there are no shards
  sidekiqShards: [],
  // If you have application logs shipped to Opensearch and want the tooling links to be generated in dashboards,
  // provide hostname and defaultIndexPattern (and optionally indexPatterns if you have specialized indexes in Opensearch)
  toolingLinks: {
    opensearchHostname: null,  // null means no links are generated in Grafana dashboards.
    defaultIndexPattern: null,  // The index pattern name where relevant logs are stored; required if hostname is not null
    indexPatterns: {},  // Optional map of index catalog entry names to index patterns, to override the defaultIndexPattern if necessary
  },

  monitoring: {
    gitaly: {
      monitoringThresholds: {
        apdexScore: 0.999,
        errorRatio: 0.9995,
      },
    },
    webservice: {
      monitoringThresholds: {
        apdexScore: 0.998,
        errorRatio: 0.999,
      },
    },
    nginx: {
      monitoringThresholds: {
        apdexScore: 0.995,
        errorRatio: 0.999,
      },
      alertWindows: ['1h', '6h', '3d'],
    },
    sidekiq: {},
  },

  apdexThresholds: {
    gitlabShell: {
      satisfied: 30,
      tolerated: 60,
    },
    gitaly: {
      satisfied: gitalyHelper.defaultSatisfiedThreshold,
      tolerated: gitalyHelper.defaultToleratedThreshold,
    },
    praefect: {
      satisfied: gitalyHelper.defaultSatisfiedThreshold,
      tolerated: gitalyHelper.defaultToleratedThreshold,
    },
  },
}
