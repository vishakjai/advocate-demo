local redisCommon = import 'gitlab-dashboards/redis_common_graphs.libsonnet';

redisCommon.redisDashboard('redis-cluster-queues-meta', cluster=true, hitRatio=false)
.overviewTrailer()
