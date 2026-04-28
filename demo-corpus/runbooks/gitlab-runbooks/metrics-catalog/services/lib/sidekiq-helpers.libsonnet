// Sidekiq Shard Definitions
// This should contain a list of sidekiq shards
local shardDefaults = {
  autoScaling: true,
  trafficCessationAlertConfig: true,
  capacityPlanning: true,
};

local shardDefinitions = {
  'database-throttled': { urgency: 'throttled', gkeDeployment: 'gitlab-sidekiq-database-throttled-v2', trafficCessationAlertConfig: false },
  'gitaly-throttled': { urgency: 'throttled', gkeDeployment: 'gitlab-sidekiq-gitaly-throttled-v2', trafficCessationAlertConfig: false },
  'low-urgency-cpu-bound': { urgency: 'low', gkeDeployment: 'gitlab-sidekiq-low-urgency-cpu-bound-v2' },
  'memory-bound': { urgency: null, gkeDeployment: 'gitlab-sidekiq-memory-bound-v2', trafficCessationAlertConfig: false },
  'import-shared-storage': { urgency: null, gkeDeployment: 'gitlab-sidekiq-import-shared-storage-v2', trafficCessationAlertConfig: false },
  quarantine: { urgency: null, gkeDeployment: 'gitlab-sidekiq-catchall-v2', trafficCessationAlertConfig: false, capacityPlanning: false },
  'urgent-cpu-bound': { urgency: 'high', gkeDeployment: 'gitlab-sidekiq-urgent-cpu-bound-v2' },
  'urgent-other': { urgency: 'high', gkeDeployment: 'gitlab-sidekiq-urgent-other-v2' },
  'urgent-authorized-projects': { urgency: 'throttled', gkeDeployment: 'gitlab-sidekiq-urgent-authorized-projects-v2', trafficCessationAlertConfig: false },
  catchall: { urgency: null, gkeDeployment: 'gitlab-sidekiq-catchall-v2' },
  'catchall-b': { urgency: null, gkeDeployment: 'gitlab-sidekiq-catchall-b-v2' },
  elasticsearch: { urgency: 'throttled', gkeDeployment: 'gitlab-sidekiq-elasticsearch-v2', trafficCessationAlertConfig: false },
  'urgent-ai-abstraction-layer': { urgency: 'high', gkeDeployment: 'urgent-ai-abstraction-layer-v1', trafficCessationAlertConfig: false },
  'urgent-ci-pipeline': { urgency: 'high', gkeDeployment: 'gitlab-sidekiq-urgent-ci-pipeline-v2' },
};

local shards = std.foldl(
  function(memo, shardName)
    memo { [shardName]: shardDefaults + shardDefinitions[shardName] { name: shardName } },
  std.objectFields(shardDefinitions),
  {}
);

local shardTrafficCessationAlertConfig = {
  component_shard: {
    shard: {
      noneOf: [
        shardName
        for shardName in std.objectFields(shards)
        if shards[shardName].trafficCessationAlertConfig == false
      ],
    },
  },
};
// These values are used in several places, so best to DRY them up
// These should be kept in sync with https://gitlab.com/gitlab-org/gitlab/-/blob/master/lib/gitlab/metrics/sidekiq_slis.rb
{
  slos: {
    urgent: {
      queueingDurationSeconds: 10,
      executionDurationSeconds: 10,
    },
    lowUrgency: {
      queueingDurationSeconds: 60,
      executionDurationSeconds: 300,
    },
    throttled: {
      // Throttled jobs don't have a queuing duration,
      // so don't add one here!
      executionDurationSeconds: 300,
    },
  },
  shards: {
    listByName():: std.objectFields(shards),

    listAll():: std.objectValues(shards),

    // List shards which match on the supplied predicate
    listFiltered(filterPredicate): std.filter(function(f) filterPredicate(shards[f]), std.objectFields(shards)),
  },
  shardTrafficCessationAlertConfig: shardTrafficCessationAlertConfig,
}
