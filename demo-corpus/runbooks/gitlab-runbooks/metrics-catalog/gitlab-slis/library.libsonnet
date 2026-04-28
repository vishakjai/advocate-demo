local sliDefinition = import 'gitlab-slis/sli-definition.libsonnet';
local stages = import 'service-catalog/stages.libsonnet';
local aggregationSet = import 'servicemetrics/aggregation-set.libsonnet';

local customersDotCategories = std.foldl(
  function(memo, group) memo + group.feature_categories,
  stages.groupsForStage('fulfillment'),
  []
);

local list = [
  sliDefinition.new({
    name: 'rails_request',
    significantLabels: ['endpoint_id', 'feature_category', 'request_urgency'],
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    description: |||
      The number of requests meeting their duration target based on the urgency
      of the endpoint. By default, a request should take no more than 1s. But
      this can be adjusted by endpoint.

      Read more about this in the [documentation](https://docs.gitlab.com/ee/development/application_slis/rails_request_apdex.html).
    |||,
  }),
  sliDefinition.new({
    name: 'security_scan',
    significantLabels: ['feature_category', 'scan_type'],
    kinds: [sliDefinition.errorRateKind],
    description: |||
      The rate at which security scanners are failing with errors.
    |||,
  }),
  sliDefinition.new({
    name: 'graphql_query',
    significantLabels: ['endpoint_id', 'feature_category', 'query_urgency'],
    kinds: [sliDefinition.errorRateKind, sliDefinition.apdexKind],
    description: |||
      A GraphQL query is executed in the context of a request. An error does not
      always result in a 5xx error. But could contain errors in the response.
      Multiple queries could be batched inside a single request.

      This SLI counts all operations, a succeeded operation does not contain errors in
      it's response or return a 500 error.

      The number of GraphQL queries meeting their duration target based on the urgency
      of the endpoint. By default, a query should take no more than 1s. We're working
      on making the urgency customizable in [this epic](https://gitlab.com/groups/gitlab-org/-/epics/5841).

      We're only taking known operations into account. Known operations are queries
      defined in our codebase and originating from our frontend.
    |||,
  }),
  sliDefinition.new({
    name: 'glql',
    significantLabels: ['endpoint_id', 'feature_category', 'query_urgency', 'error_type'],
    kinds: [sliDefinition.errorRateKind, sliDefinition.apdexKind],
    featureCategory: 'markdown',
    description: |||
      A GLQL query runs as part of a GraphQL request. Not every error results in a 5xx;
      sometimes errors are simply returned in the response.
      Although multiple queries can be batched in one request,
      GLQL uses TaskQueue to ensure only one query per request is handled.

      At the moment, the query urgency is inherited from GraphQL and is set as 'low'
      https://gitlab.com/gitlab-org/gitlab/-/blob/master/app/controllers/graphql_controller.rb#L59

      The current possible values for feature_category are: code_review_workflow, not_owned,
      portfolio_management, team_planning, and wiki.

      Invalid GLQL queries (for example, due to syntax errors) do not count toward the error budget.
      We specifically monitor ActiveRecord::QueryAborted errors because they indicate timeouts;
      if a query times out, our rate limiter throttles it. Throttled responses do not count
      towards the error budget.
    |||,
  }),
  sliDefinition.new({
    name: 'customers_dot_sidekiq_jobs',
    significantLabels: ['endpoint_id', 'feature_category'],
    dashboardFeatureCategories: customersDotCategories,
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    description: |||
      The number of CustomersDot jobs meeting their duration target for their execution.
      By default, a Sidekiq job should take no more than 5 seconds. But
      this can be adjusted by endpoint.
    |||,
  }),
  sliDefinition.new({
    name: 'customers_dot_requests',
    significantLabels: ['endpoint_id', 'feature_category'],
    dashboardFeatureCategories: customersDotCategories,
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    description: |||
      The number of CustomersDot requests meeting their duration target based on the urgency
      of the endpoint. By default, a request should take no more than 0.4s. But
      this can be adjusted by endpoint.
    |||,
  }),
  sliDefinition.new({
    name: 'global_search',
    significantLabels: ['endpoint_id', 'search_level', 'search_scope', 'search_type'],
    kinds: [sliDefinition.apdexKind],
    featureCategory: 'global_search',
    description: |||
      The number of Global Search search requests meeting their duration target based on the 99.95th percentile of
      the search with the same parameters.
    |||,
  }),
  sliDefinition.new({
    name: 'global_search_indexing',
    significantLabels: ['document_type'],
    kinds: [sliDefinition.apdexKind],
    featureCategory: 'global_search',
    description: |||
      The number of Global Search indexing calls meeting their duration target based on the 99.95th percentile of
      indexing. This indicates the duration between when an item was changed and when it became available in Elasticsearch.

      This indexing duration is measured in the Sidekiq job triggering the indexing in ElasticSearch.

      The target duration can be found here:
      https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/gitlab/metrics/global_search_indexing_slis.rb#L14-L15
    |||,
  }),
  sliDefinition.new({
    name: 'sidekiq_execution',
    significantLabels: ['worker', 'feature_category', 'urgency', 'external_dependencies', 'queue'],
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    description: |||
      The number of Sidekiq jobs meeting their execution duration target based on the urgency of the worker.
      By default, execution of a job should take no more than 300 seconds. But this can be adjusted by the
      urgency of the worker.

      Read more about this in the [runbooks doc](https://runbooks.gitlab.com/sidekiq/sidekiq-slis/).
    |||,
  }),
  sliDefinition.new({
    name: 'sidekiq_queueing',
    significantLabels: ['worker', 'feature_category', 'urgency', 'external_dependencies', 'queue'],
    kinds: [sliDefinition.apdexKind],
    description: |||
      The number of Sidekiq jobs meeting their queueing duration target based on the urgency of the worker.
      By default, queueing of a job should take no more than 5 minutes for low urgency work, or 5 seconds for
      high urgency work.

      Read more about this in the [runbooks doc](https://runbooks.gitlab.com/sidekiq/sidekiq-queueing-apdex/).
    |||,
  }),
  sliDefinition.new({
    name: 'sidekiq_execution_with_external_dependency',
    counterName: 'sidekiq_execution',  // Reusing sidekiq_execution as counter name
    significantLabels: ['worker', 'feature_category', 'urgency', 'external_dependencies'],
    featureCategory: 'not_owned',

    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    description: |||
      The number of Sidekiq jobs with external dependencies across all shards meeting their execution duration target based on the urgency of the worker.
      By default, execution of a job should take no more than 300 seconds. But this can be adjusted by the
      urgency of the worker.

      Read more about this in the [runbooks doc](https://runbooks.gitlab.com/sidekiq/sidekiq-slis/).
    |||,
  }),
  sliDefinition.new({
    name: 'sidekiq_queueing_with_external_dependency',
    counterName: 'sidekiq_queueing',  // Reusing sidekiq_queueing as counter name
    significantLabels: ['worker', 'feature_category', 'urgency', 'external_dependencies'],
    featureCategory: 'not_owned',
    kinds: [sliDefinition.apdexKind],
    description: |||
      The number of Sidekiq jobs with external dependencies across all shards meeting their queueing duration target based on the urgency of the worker.
      By default, queueing of a job should take no more than 60 seconds. But this can be adjusted by the
      urgency of the worker.

      Read more about this in the [runbooks doc](https://runbooks.gitlab.com/sidekiq/sidekiq-slis/).
    |||,
  }),
  sliDefinition.new({
    name: 'llm_completion',
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    significantLabels: ['feature_category', 'service_class'],
    featureCategory: 'ai_abstraction_layer',
    description: |||
      These signifies operations that reach out to a language model with a prompt. These interactions
      with an AI provider are executed within `Llm::CompletionWorker`-jobs. The worker could execute multiple
      requests to an AI provider for a single operation.

      A success means that we were able to present the user with a response that is delivered to a client that is
      subscribed to a websocket. An error could be that the AI-provider is not responding, or is erroring.

      For the apdex, we consider an operation fast enough if we were able to get a complete response from the AI provider within
      20 seconds. This does not include the time it took for the Sidekiq job to get picked up, or the time it took to deliver
      the response to the client.

      The `service_class` label on the source metrics tells us which AI related features the operation is for.

      These operations do not go through the API gateway yet, but will in the future.
    |||,
  }),
  sliDefinition.new({
    name: 'llm_chat_first_token',
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    significantLabels: ['feature_category', 'service_class'],
    featureCategory: 'duo_chat',
    description: |||
      These signifies Time to First Token (TTFT) for Duo Chat,
      from when chat is first received, till we send out the first token.

      A success means that we send out the first token.

      An error could be that the AI-provider is not responding, or is erroring.

      For the apdex, we consider it fast enough if first token is sent to user within 5 seconds.
      This includes the time it took for the Sidekiq job to get picked up.
      This does not include the time it took to deliver the response to the client.
    |||,
  }),
  sliDefinition.new({
    name: 'client_database_transaction',
    counterName: 'db_transaction',
    significantLabels: ['worker', 'feature_category', 'urgency', 'external_dependencies', 'db_config_name'],
    featureCategory: 'not_owned',
    kinds: [sliDefinition.apdexKind],
    description: |||
      This tracks the largest database transaction duration from the client's perspective.

      A success means that every database transaction within a Sidekiq job is below the threshold duration. A failure would mean
      at least one database transaction within the Sidekiq job has exceeded the threshold duration.
    |||,
  }),
  sliDefinition.new({
    name: 'ci_deleted_objects_processing',
    kinds: [sliDefinition.apdexKind, sliDefinition.errorRateKind],
    significantLabels: ['feature_category'],
    featureCategory: 'continuous_integration',
    description: |||
      This SLI signifies operations that destroy job artifacts that have been marked ready for deletion.

      A success means that the artifact was destroyed within an acceptable delay
      (within 12 hours of being marked ready for deletion).

      An error means the artifact was not destroyed.

      There can be cases when an artifact is destroyed but exceeds the threshold for an acceptable delay.
      In this case, the error is recorded as false and the apdex success is recorded as false.

      More Information: https://runbooks.gitlab.com/ci_deleted_objects_processing/deleted_objects_processing_triage/
    |||,
  }),
];

local definitionsByName = std.foldl(
  function(memo, definition)
    assert !std.objectHas(memo, definition.name) : '%s already defined' % [definition.name];
    memo { [definition.name]: definition },
  list,
  {}
);

{
  get(name):: definitionsByName[name],
  all:: list,
  names:: std.map(function(sli) sli.name, list),
}
