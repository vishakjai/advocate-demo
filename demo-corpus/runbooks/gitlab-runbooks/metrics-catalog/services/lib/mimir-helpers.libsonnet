local metricsConfig = import 'gitlab-metrics-config.libsonnet';
local strings = import 'utils/strings.libsonnet';

{
  mimirDatasource(tenantId)::
    assert std.setMember(tenantId, metricsConfig.mimirTenants) :
           'invalid tenantId %s. Available tenants: %s' % [tenantId, metricsConfig.mimirTenants];
    // This format has to match
    // https://ops.gitlab.net/gitlab-com/gl-infra/terraform-modules/observability/observability-tenants/-/blob/main/grafana.tf?ref_type=heads#L5
    'Mimir - %(tenant)s' % strings.title(std.strReplace(tenantId, '-', ' ')),
}
