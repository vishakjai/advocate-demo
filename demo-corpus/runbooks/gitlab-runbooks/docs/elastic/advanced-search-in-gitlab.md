# Advanced Search

## Quickstart

### Advanced search admin page

Go to GitLab's Admin panel and navigate to Settings -> [General settings] -> Advanced search -> [Expand] (URL: `https://gitlab.com/admin/application_settings/advanced_search`)

## How-to guides

### Enabling Advanced search

Before you make any changes to config and click save, make sure you are aware of which namespaces will be indexed! consider:

- If you enable Advanced search by using the `Elasticsearch indexing` checkbox and selecting save, the entire instance will be indexed
- If you only want to enable indexing for a specific namespace, use the `Elasticsearch indexing restrictions` feature and only then click save
- In order to allow for initial indexing to take place (which depending on the size of the instance can take a few hours/days) without breaking the search feature, do not enable searching with Elasticsearch. Do it after the initial indexing completes.

You can tell which sidekiq jobs are from initial indexing by looking at `json.meta.user` in the sidekiq logs.

### Enabling/Disabling Advanced search functionality

Advanced search has a few administration controls (available through the admin UI and rake tasks) and feature flags which can be used to control different functions of Advanced search.

#### Enabling/Disabling Advanced search

Two examples of when this is useful:

 1. During initial indexing
 1. During an incident where users are unable to use the search functionality or if the Elasticsearch instance is unreachable.

##### Rake tasks

- `gitlab:elastic:disable_search_with_elasticsearch`
- `gitlab:elastic:enable_search_with_elasticsearch`

##### Admin UI

1. Go to Advanced search admin page (see above)
1. Uncheck the `Search with Elasticsearch enabled` checkbox
1. Select save
1. All search queries should now use the regular Gitlab search mechanism backed by the database.

_Note:_ Global and group search functionality will be limited for some search scopes.

#### Pausing Advanced search indexing

An example of when this is useful is during an incident where there is a high number of indexing failures or if the Elasticsearch instance is unreachable. Indexing jobs will not be lost, the jobs are stored in a separate ZSET and re-enqueued when indexing is unpaused.

##### Rake tasks

- `gitlab:elastic:pause_indexing`
- `gitlab:elastic:resume_indexing`

##### Admin UI

1. Go to Advanced search admin page (see above)
1. Check `Pause Elasticsearch indexing`
1. Select save

_Note:_ Global and group search functionality will be limited in some search scopes.

#### Disabling Advanced search indexing

Advanced search indexing can be completely disabled. **Pausing indexing** is the preferred method.

WARNING:
Indexed data will be stale after indexing is re-enabled. Reindexing from scratch may be necessary to ensure up to date search results.

#### Admin UI

1. Go to Advanced search admin page (see above)
1. Uncheck `Elasticsearch indexing`
1. Click save

#### Pausing Advanced search migrations

An example of when this is useful is when an Advanced search migration is not working or is causing performance degredation in the Elasticsearch cluster. Pausing the migrations can allow a revert to process while also allowing the system to recover. This is only useful if there are Advanced search migrations running.

Use this rake task to check for pending migrations: `gitlab:elastic:list_pending_migrations`

#### Feature flag

The `Elastic::MigrationWorker` is responsible for running migrations. It can be paused using application settings by running `ApplicationSetting.current.update(elastic_migration_worker_enabled: false)` in rails console or by [deferring the Sidekiq worker](https://gitlab.com/gitlab-com/runbooks/-/blob/master/docs/sidekiq/alerts/SidekiqQueueTooLarge.md?ref_type=heads#examples-of-disabling-workers-via-chatops)

### Creating and removing indices

#### Creating an index (shards considerations)

[The `gitlab:elastic:index` rake task](https://docs.gitlab.com/ee/integration/elasticsearch.html#gitlab-elasticsearch-rake-tasks) that creates multiple indexes and also sets up mappings for each index. The easiest way to create everything is by using the rake task rather than creating each index manually. If you don't use that rake task, you'll have to create mappings for each index yourself!

The rake task actually will schedule 4 other tasks, which includes index_snippets which will index all index_snippets. Make sure this is what you want.

You can only split the index if you have a sufficient number of routing_shards. The number_of_routing_shards translates to the number of keys in the hashing table so it cannot be adjusted after the index has been created.

ELK 7.x by default uses a very high number of routing shards which allows you to split the index.

#### Removing an index

Removing can be done through kibana's index management page

#### Recreating an index

The `gitlab:elastic:index` rake task can be used as a [last resort to recreate the index from scratch](https://docs.gitlab.com/ee/integration/advanced_search/elasticsearch_troubleshooting.html#last-resort-to-recreate-an-index).

### Shards management

At the moment, data is distributed across shards unevenly [7238](https://gitlab.com/gitlab-org/gitlab-ee/issues/7238) , [3217](https://gitlab.com/gitlab-org/gitlab-ee/issues/3217) , [2957](https://gitlab.com/gitlab-org/gitlab-ee/issues/2957)

If needed, rebalancing of shards can be done through API

### Cleaning up index

Q: Will we ever remove data from the index? e.g. when a project is removed from GitLab instance? Do we not care about leftovers? How can we monitor how much data is stale?

A: Data is removed from the Elasticsearch index when it is removed from the GitLab database or filesystem. When a project is removed, we delete corresponding documents from the index. Similarly, if an issue is removed, then the Elasticsearch document for that index is also removed. The only way to discover if a particular document in Elasticsearch is stale compared to the database is to cross-reference between the two. There's nothing automatic for that at present, and it sounds expensive to do.

### Triggering indexing

Once a namespace is enabled sidekiq jobs will be scheduled for it.

If triggering initial indexing manually, it has to be done for both git repos and database objects

Rake tasks: `./ee/lib/tasks/gitlab/elastic.rake`

Using external indexer (rake task) -> you can limit the list of projects to be indexed to project ids range (see Elastic integration docs) or limit the indexer to specific namespaces in the gitlab admin panel

You cannot be selective about what is processed, you can only limit which projects are processed

Gitlab won't be indexing anything if no namespaces are enabled, so we can enable Advanced search and add URL with credentials later. This is to prevent a situation where Advanced search is enabled but no credentials are available

#### Impact on GitLab

#### Sidekiq workers impact

Add more workers that will process the elastic queues. How much resources do those jobs need? hey are not time critical, but they are very bursty

#### Gitaly impact

Should be controlled with Sidekiq concurency

#### Impact on Elasticsearch cluster

Estimate number of requests -> measure impact on Elasticsearch

## Concepts

### Advanced search docs and video

More detailed instructions and docs: <https://docs.gitlab.com/ee/integration/advanced_search/elasticsearch.html>

ES integration deep dive video: <https://www.youtube.com/watch?reload=9&v=vrvl-tN2EaA>

### Indexer

#### Overview

Indexing happens in two scenarios:

- initial indexing - Triggered by adding namespaces or by manually running rake tasks.
- incremental indexing - Triggered by new events (e.g. git push, create/updates issues)

For non-repository data (e.g. issues, merge requests), the records are queued into a redis sorted ZSET and processed by Sidekiq cron workers.

For repository data (e.g. code, wikis), Sidekis jobs are scheduled to index data using the go indexer for each project.

The indexer binary used by Sidekiq jobs is delivered as part of omnibus:

- go indexer, `/opt/gitlab/embedded/bin/gitlab-elasticsearch-indexer`, uses a connection to gitaly

#### Sidekiq jobs

Examples of indexer jobs:

- `ee/app/workers/elastic_indexer_worker.rb`
- `ee/app/workers/elastic_commit_indexer_worker.rb`
- `ee/app/workers/elastic_batch_project_indexer_worker.rb`
- `ee/app/workers/elastic_namespace_indexer_worker.rb`
- `ee/app/workers/elastic_index_bulk_cron_worker.rb`

Logs available in centralised logging, see [Logging](../logging/README.md)

#### Elastic_indexer_worker.rb

- Triggered by application events (except epics), e.g. comments, issues
- Processes database

#### Elastic_commit_indexer_worker.rb

- Triggered by commits to git repo
- Processes the git repo data accessed over gitaly
- Uses external binary

#### Elastic_index_bulk_cron_worker.rb

- Triggered by sidekiq-cron every minute
- Processes incremental updates for database records, does not process initial
  indexing of new groups/projects
- Consumes a custom Redis queue implemented as a sorted set.
  The correct way to see the size is from the rails console using
  `Elastic::ProcessBookkeepingService.queue_size`

## Incident Management

### High CPU Usage

When there is high CPU usage across all the Elasticsearch data nodes, here are the suggested steps to mitigate the issue

- Check Slow logs to see whether there are obvious indicators that can be used to identify the possible root cause. To view the Slow logs, login the Elastic Cloud console. In the `monitoring-cluster` cluster, you will find the production Elasticsearch cluster with `gprd-indexing` prefix in name and staging cluster with `gstg-indexing`. The Slow logs are under each of the Elasticsearch data nodes. Note: make sure you have access to the Elastic Cloud login credentials.
- If the Slow logs can't help you fix the high CPU usage issue, you may consider restarting the Elasticsearch cluster.
  - You may want to capture the thread dumps by following [the Elastic documentation](https://www.elastic.co/guide/en/cloud-enterprise/current/ece-capture-thread-dumps.html).
  - Cancel the running tasks via [Elasticsearch API](https://www.elastic.co/guide/en/elasticsearch/reference/current/tasks.html#task-cancellation)
  - Go to GitLab.com instance Admin UI, [pause the Elasticsearch indexing](https://docs.gitlab.com/ee/integration/advanced_search/elasticsearch.html#advanced-search-configuration)
  - Go to the Elastic Cloud login page, click the `Manage` link under Actions column corresponding to the deployment under `Dedicated deployments` table. Click the `Actions` button on the top-right corner of the deployment page and click `Restart Elasticsearch`. In the popop window, choose `Full restart`. Please note, there are two other `No Downtime` restart options, `Restart instances one at a time` and `Restart all instances within an availability zone, before moving on to the next zone`. But, according to our experience, they may take much longer time than `Full restart`. Since the Advanced Search requests are very likely to time out in high CPU situation, `Full restart` will actually bring the service back quicker. The pausing indexing step above will also help minimize the impact of potential data loss during the `Downtime`.
  - Monitor the CPU usage of the cluster nodes. [Unpause indexing](https://docs.gitlab.com/ee/integration/advanced_search/elasticsearch.html#unpause-indexing) from the GitLab instance's Admin UI after CPU usage is back to normal.
  - File an Elastic Support ticket with the thread dumps taken in the step above.

### Indexing queue backing up

When the one of the indexing queues (initial,  incremental, or embeddings) is backing up and indexing is not paused, it may be due to errors serializing documents for indexing. Look for [errors in Kibana](https://log.gprd.gitlab.net/app/r/s/UVyNT) that follow this pattern:

- `json.class.keyword`
  - `ElasticIndexBulkCronWorker`
  - `ElasticIndexInitialBulkCronWorker`
  - `Search::ElasticIndexEmbeddingBulkCronWorker`
- `json.exception.class.keyword` = `NoMethodError`
- `json.exception.message` = `undefined method...`

It's likely that only one data type is affected. Note the method name causing the error and find the data type class by looking at `json.exception.backtrace`. Once you have the class and method, run the following script to find the records causing issues.

```ruby
# Each queue uses it's own Service class.
# Update the example below with the appropricate class
# initial => Elastic::ProcessInitialBookkeepingService
# incremental => Elastic::ProcessBookkeepingService
# embeddings => Search::Elastic::ProcessEmbeddingBookkeepingService

items = Elastic::ProcessBookkeepingService.queued_items
affected_klass = CLASS_FROM_LOGS
affected_method = METHOD_FROM_LOGS

to_remove = {}.tap do |hash|
  items.each do |shard, refs|

    refs.each do |ref, _|
      reference = Search::Elastic::Reference.deserialize(ref)
      klass = reference.klass
      next unless affected_klass == klass

      id = reference.identifier
      db_record = affected_klass.find_by_id(id)
      next unless db_record
      next if db_record.respond_to?(affected_method) && db_record.public_send(affected_method)

      hash[shard] ||= []
      hash[shard] << ref
    end
  end
end
```

Once the data has been validated, run the following script to remove the records from the queue.

```ruby
Gitlab::Redis::SharedState.with do |redis|
  to_remove.each do |shard, refs|
    refs.each do |ref|
      redis.zrem Elastic::ProcessBookkeepingService.redis_set_key(shard), ref.first
    end
  end
end
```

The indexing queue should drain slowly once the records have been cleared from the queue. It is
important to understand what caused the records to be queued for indexing. An issue must be opened
to ensure the records do not get indexed again or the issue will reoccur.

### Shard reassignment failure

When shard allocation fails the [Cluster Reroute API](https://www.elastic.co/guide/en/elasticsearch/reference/current/cluster-reroute.html) may be used to retry failed shard allocation. The API request may be run as a curl command or from the Elasticsearch UI DevTools Console

```
curl -XPOST "$ELASTIC_URL/_cluster/reroute?retry_failed"
```
