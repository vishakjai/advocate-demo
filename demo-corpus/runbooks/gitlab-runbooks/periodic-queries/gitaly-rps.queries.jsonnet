local periodicQuery = import './periodic-query.libsonnet';
local datetime = import 'utils/datetime.libsonnet';

local now = std.extVar('current_time');

{
  gitaly_rate_5m: periodicQuery.new({
    requestParams: {
      query: |||
        avg_over_time(gitlab_service_ops:rate_5m{env="gprd",environment="gprd",monitor="global",stage="main",type="gitaly"}[1h])
      |||,
      time: now,
    },
  }),
}
