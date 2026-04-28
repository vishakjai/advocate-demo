local gitlabMetricsConfig = (import 'gitlab-metrics-config.libsonnet');

local all =
  [
    import 'gitaly.jsonnet',
    import 'gitlab-shell.jsonnet',
    import 'redis.jsonnet',
    import 'registry.jsonnet',
    import 'sidekiq.jsonnet',
    import 'webservice.jsonnet',
    import 'kube.jsonnet',
    import 'nginx.jsonnet',
    import 'secrets-manager.jsonnet',
  ] + (
    if gitlabMetricsConfig.options.elasticacheMonitoring then
      [import 'aws-elasticache.jsonnet']
    else
      []
  ) + (
    if gitlabMetricsConfig.options.rdsMonitoring then
      [import 'aws-rds.jsonnet']
    else
      []
  ) + (
    if gitlabMetricsConfig.options.praefect.enable then
      [import 'praefect.jsonnet']
    else
      []
  ) + (
    if gitlabMetricsConfig.options.consul.enable then
      [import 'consul.jsonnet']
    else
      []
  ) +
  std.get(gitlabMetricsConfig.options, 'services', []);

// Sort services
std.sort(all, function(f) f.type)
