local redisCommon = import 'gitlab-dashboards/redis_common_graphs.libsonnet';

redisCommon.redisDashboard('redis-cluster-feature-flag', cluster=true, hitRatio=true)
.overviewTrailer()
