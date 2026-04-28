local redisCommon = import 'gitlab-dashboards/redis_common_graphs.libsonnet';

redisCommon.redisDashboard('redis-sidekiq', cluster=false, sharded=true)
.overviewTrailer()
