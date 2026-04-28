{
  apdex: (import './apdex-panel.libsonnet').panel,
  errorRatio: (import './error-ratio-panel.libsonnet').panel,
  operationRate: (import './operation-rate-panel.libsonnet').panel,
  saturationDetail: (import './saturation_detail.libsonnet').panel,
  utilizationRate: (import './utilization-rates-panel.libsonnet').panel,
}
