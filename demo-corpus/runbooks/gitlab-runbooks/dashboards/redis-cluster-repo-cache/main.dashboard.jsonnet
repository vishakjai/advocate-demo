local redisCommon = import 'gitlab-dashboards/redis_common_graphs.libsonnet';

redisCommon.redisDashboard('redis-cluster-repo-cache', cluster=true, hitRatio=true)
.overviewTrailer()
