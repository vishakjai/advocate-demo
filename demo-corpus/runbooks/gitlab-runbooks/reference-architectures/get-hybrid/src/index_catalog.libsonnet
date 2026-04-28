local toolingLinksConfig = (import 'gitlab-metrics-config.libsonnet').options.toolingLinks;
local matching = import 'elasticlinkbuilder/matching.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';

local rangeFilter = matching.rangeFilter;
local matchFilter = matching.matchFilter;
local matchInFilter = matching.matchInFilter;
local existsFilter = matching.existsFilter;
local mustNot = matching.mustNot;
local matchAnyScriptFilter = matching.matchAnyScriptFilter;
local matcher = matching.matcher;

local statusCode(field) =
  [rangeFilter(field, gteValue=500, lteValue=null)];

local indexPattern(indexName) =
  local indexPatterns = std.get(std.prune(toolingLinksConfig), 'indexPatterns', {});
  std.get(indexPatterns, indexName, toolingLinksConfig.defaultIndexPattern);

local indexDefaults = {
  defaultFilters: [],
  kibanaEndpoint: 'https://' + toolingLinksConfig.opensearchHostname + '/_dashboards/app/',
  discoverEndpoint: 'discover#/',
  visualizeEndpoint: 'visualize#',
  timestamp: '@timestamp',
  prometheusLabelMappings: {},
  prometheusLabelTranslators: {},
};

{
  gitaly: indexDefaults {
    defaultColumns: ['hostname', 'grpc.method', 'grpc.request.glProjectPath', 'grpc.code', 'grpc.time_ms'],
    defaultSeriesSplitField: 'grpc.method.keyword',
    failureFilter: [mustNot(matchInFilter('grpc.code', ['OK', 'NotFound', 'Unauthenticated', 'AlreadyExists', 'FailedPrecondition', 'DeadlineExceeded', 'Canceled', 'InvalidArgument', 'PermissionDenied', 'ResourceExhausted'])), existsFilter('grpc.code')],
    indexPattern: indexPattern('gitaly'),
    slowRequestFilter: [matchFilter('msg', 'unary')],
    defaultLatencyField: 'grpc.time_ms',
    prometheusLabelMappings+: {
      fqdn: 'fqdn',
    },
    latencyFieldUnitMultiplier: 1000,
  },

  kas: indexDefaults {
    defaultColumns: ['msg', 'project_id', 'commit_id', 'number_of_files', 'grpc.time_ms'],
    defaultSeriesSplitField: 'grpc.method.keyword',
    failureFilter: [existsFilter('error')],
    indexPattern: indexPattern('kas'),
  },

  nginx: indexDefaults {
    defaultColumns: ['remote', 'request_time', 'code', 'upstream_status', 'method', 'path', 'message'],
    defaultSeriesSplitField: 'remote',
    failureFilter: statusCode('code'),
    defaultLatencyField: 'request_time',
    indexPattern: indexPattern('nginx'),
    latencyFieldUnitMultiplier: 1,
  },

  pages: indexDefaults {
    defaultColumns: ['hostname', 'pages_domain', 'host', 'pages_host', 'path', 'remote_ip', 'duration_ms'],
    defaultSeriesSplitField: 'pages_host.keyword',
    failureFilter: statusCode('status'),
    defaultLatencyField: 'duration_ms',
    indexPattern: indexPattern('pages'),
    latencyFieldUnitMultiplier: 1000,
  },

  rails: indexDefaults {
    defaultColumns: [
      'status',
      'method',
      'meta.caller_id',
      'meta.feature_category',
      'path',
      'request_urgency',
      'duration_s',
      'target_duration_s',
    ],
    defaultSeriesSplitField: 'meta.caller_id.keyword',
    failureFilter: statusCode('status'),
    defaultLatencyField: 'duration_s',
    indexPattern: indexPattern('rails'),
    latencyFieldUnitMultiplier: 1,
    // The GraphQL requests are in the rails_graphql index and look slightly
    // different.
    defaultFilters: [mustNot(matchFilter('json.controller', 'GraphqlController'))],
    slowRequestFilter: [
      // These need to be present for the script to work.
      // Health check requests don't have a target_duration_s
      // This filters these out of the logs
      existsFilter('target_duration_s'),
      existsFilter('duration_s'),
      matching.matchers({ anyScript: ["doc['duration_s'].value > doc['target_duration_s'].value"] }),
    ],

    prometheusLabelMappings+: {
      stage_group: 'meta.feature_category',
      feature_category: 'meta.feature_category',
    },
  },

  rails_graphql: self.rails {
    defaultSeriesSplitField: 'meta.caller_id.keyword',
    defaultColumns: ['meta.caller_id', 'operation_name', 'meta.feature_category', 'operation_fingerprint', 'duration_s'],
    defaultFilters: [matchFilter('json.controller', 'GraphqlController')],
    failureFilter: [existsFilter('graphql_errors.message')],
    indexPattern: indexPattern('rails_graphql'),
  },

  registry: indexDefaults {
    defaultColumns: ['remote_ip', 'duration_ms', 'code', 'msg', 'status', 'error', 'method', 'uri'],
    defaultSeriesSplitField: 'remote_ip.keyword',
    failureFilter: statusCode('status'),
    defaultLatencyField: 'duration_ms',
    indexPattern: indexPattern('registry'),
    latencyFieldUnitMultiplier: 1000,
  },

  shell: indexDefaults {
    defaultColumns: ['command', 'msg', 'level', 'gl_project_path', 'error'],
    defaultSeriesSplitField: 'gl_project_path.keyword',
    failureFilter: [matchFilter('level', 'error')],
    indexPattern: indexPattern('shell'),
  },

  sidekiq: indexDefaults {
    defaultColumns: ['class', 'queue', 'meta.project', 'meta.feature_category', 'job_status', 'queue_duration_s', 'duration_s'],
    defaultSeriesSplitField: 'meta.feature_category.keyword',
    failureFilter: [matchFilter('job_status', 'fail')],
    defaultLatencyField: 'duration_s',
    indexPattern: indexPattern('sidekiq'),
    latencyFieldUnitMultiplier: 1,
  },

  workhorse: indexDefaults {
    defaultColumns: ['method', 'remote_ip', 'status', 'uri', 'duration_ms'],
    defaultSeriesSplitField: 'remote_ip.keyword',
    failureFilter: statusCode('status'),
    defaultLatencyField: 'duration_ms',
    indexPattern: indexPattern('workhorse'),
    latencyFieldUnitMultiplier: 1000,
  },
}
