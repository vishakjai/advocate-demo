// Labels set by
// https://gitlab.com/gitlab-com/gl-infra/platform/runway/runwayctl/-/blob/main/reconciler/templates/otel-config.yaml.tftpl
local regionalLabels = [
  'region',
];

{
  labels(service):: if service.regional then regionalLabels else [],
}
