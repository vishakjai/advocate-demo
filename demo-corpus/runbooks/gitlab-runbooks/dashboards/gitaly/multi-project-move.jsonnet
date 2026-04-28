local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local panel = import 'grafana/time-series/panel.libsonnet';
local selectors = import 'promql/selectors.libsonnet';

local row = grafana.row;

// Selector for the gitalyctl container runing in ops.
local gitalyctlSelectorHash = {
  environment: 'ops',
  env: 'ops',
  namespace: 'gitalyctl',
  container: 'gitalyctl',
};
local gitalyctlSelector = selectors.serializeHash(gitalyctlSelectorHash);

// There are different types of repositories that we are moving, and we want to
// templatize what we monitor on each repository type move.
local repsitoryTypeRates(repoType) =
  [
    panel.timeSeries(
      title='Active moves',
      description='Total number of moves per storage that are currently happening.',
      query=|||
        sum by (storage) (gitalyctl_%(repoType)s_active_repository_moves{%(gitalyctlSelector)s})
      ||| % { repoType: repoType, gitalyctlSelector: gitalyctlSelector },
      legendFormat='{{ storage }}'
    ),
    panel.timeSeries(
      title='Success rate',
      description='Rate/sec of successful %(repoType)s repository moves.' % { repoType: repoType },
      query=|||
        sum by (storage) (rate(gitalyctl_%(repoType)s_successful_repository_moves_total{%(gitalyctlSelector)s}[$__rate_interval]))
      ||| % { repoType: repoType, gitalyctlSelector: gitalyctlSelector },
      legendFormat='{{ storage }}'
    ),
    panel.timeSeries(
      title='Failure rate',
      description='Rate/sec of failed %(repoType)s repository moves.' % { repoType: repoType },
      query=|||
        sum by (storage) (rate(gitalyctl_%(repoType)s_failed_repository_moves_total{%(gitalyctlSelector)s}[$__rate_interval]))
      ||| % { repoType: repoType, gitalyctlSelector: gitalyctlSelector },
      legendFormat='{{ storage }}'
    ),
    panel.timeSeries(
      title='Wait timeout rate',
      description="Rate/sec of %(repoType)s repository moves that tiemout. The timeout is set by project.move_timeout configuration. However, reaching this timeout doesn't necessarily indicate the success or failure of the repository move." % { repoType: repoType },
      query=|||
        sum by (storage) (rate(gitalyctl_%(repoType)s_timed_out_repository_moves_total{%(gitalyctlSelector)s}[$__rate_interval]))
      ||| % { repoType: repoType, gitalyctlSelector: gitalyctlSelector },
      legendFormat='{{ storage }}'
    ),
  ];

// There are different types of repositories which have different concurrency
// values.
local concurrencyByRepositoryType(repoType) =
  basic.statPanel(
    panelTitle='%(repoType)s Concurrency' % { repoType: std.asciiUpper(repoType[0]) + repoType[1:] },
    title='',
    color='',
    query=|||
      gitalyctl_%(repoType)s_repository_concurrency{%(gitalyctlSelector)s}
    ||| % { repoType: repoType, gitalyctlSelector: gitalyctlSelector },
    colorMode='none',
    noValue='Not Configured'
  );

basic.dashboard(
  'Gitaly multi-project move',
  tags=['gitaly', 'type:gitaly'],
)
.addPanel(
  row.new(title='Migration Status'),
  gridPos={
    x: 0,
    y: 1000,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Repositories on old Gitaly VMs',
        description='Total number of repositories that are on the old Gitaly VMs that we are migrating away from.',
        query=|||
          sum (gitaly_total_repositories_count{%(gitalyctlSelector)s})
        ||| % { gitalyctlSelector: selectors.serializeHash({ env: '$environment', environment: '$environment', type: 'gitaly', fqdn: { re: 'file-(marquee-)?\\\\d+-stor-.*' }, prefix: { re: '@.*' } }) },
        legendFormat='sum',
      ),
      panel.timeSeries(
        title='Repositories on new Gitaly VMs',
        description='Total number of repositories that we have on the new Gitaly VMs.',
        query=|||
          sum (gitaly_total_repositories_count{%(gitalyctlSelector)s})
        ||| % { gitalyctlSelector: selectors.serializeHash({ env: '$environment', environment: '$environment', type: 'gitaly', fqdn: { re: 'gitaly-.*-stor-.*' }, prefix: { re: '@.*' } }) },
        legendFormat='sum',
      ),
      basic.text(
        title='REDME',
        mode='markdown',
        content=|||
          ## Introduction

          This dashboard is to track progress for the [multi-project Gitaly](https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/935) epic
          to migrate from the old infrastructure to the new infrastructure.

          You can track how many repositories we have on the old Gitaly VMs and
          new Gitaly VMs and check the rate at which we are moving
          these repositories below. Any failures on moving a repository will show up below as well, and you
          can check the logs for the failure reason.

          ## Debugging

          - 🪵 [`gitalyctl` Logs](https://dashboards.gitlab.net/explore?orgId=1&left=%7B%22datasource%22:%22R8ugoM-Vk%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bnamespace%3D%5C%22gitalyctl%5C%22%7D%20%7C%3D%20%60%60%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22R8ugoM-Vk%22%7D,%22editorMode%22:%22builder%22%7D%5D,%22range%22:%7B%22from%22:%22now-7d%22,%22to%22:%22now%22%7D%7D)
          - [🔥 `gitalyctl` Error Logs](https://dashboards.gitlab.net/explore?orgId=1&left=%7B%22datasource%22:%22R8ugoM-Vk%22,%22queries%22:%5B%7B%22refId%22:%22A%22,%22expr%22:%22%7Bnamespace%3D%5C%22gitalyctl%5C%22%7D%20%7C%20json%20level%3D%5C%22level%5C%22%20%7C%20level%20%3D%20%60error%60%22,%22queryType%22:%22range%22,%22datasource%22:%7B%22type%22:%22loki%22,%22uid%22:%22R8ugoM-Vk%22%7D,%22editorMode%22:%22builder%22%7D%5D,%22range%22:%7B%22from%22:%22now-7d%22,%22to%22:%22now%22%7D%7D)
          - [💿 `gstg` API logs](https://nonprod-log.gitlab.net/app/r/s/mGwlo)
          - [💿 `gprd` API logs](https://log.gprd.gitlab.net/app/r/s/nVbro)
          - [🦵 `gstg` sidekiq logs for repository moves](https://nonprod-log.gitlab.net/app/r/s/GS5F1)
          - [🦵 `gprd` sidekiq logs for repository moves](https://log.gprd.gitlab.net/app/r/s/2E90v)

          ## References

          - [Epic](https://gitlab.com/groups/gitlab-com/gl-infra/-/epics/935)
          - [Design Doc](https://gitlab.com/gitlab-com/gl-infra/readiness/-/blob/master/library/gitaly-multi-project/README.md)
          - [Issue Board](https://gitlab.com/groups/gitlab-com/gl-infra/-/boards/5908541?label_name[]=WG%3A%3ADisasterRecovery&group_by=epic)
        |||,
      ),
    ],
    startRow=1001,
    cols=3,
  )
)
.addPanel(
  row.new(title='gitalyctl concurrency'),
  gridPos={
    x: 0,
    y: 1100,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid([
    basic.statPanel(
      panelTitle='Storage Concurrency',
      title='',
      color='',
      query=|||
        gitalyctl_projects_storage_concurrency{%(gitalyctlSelector)s}
      ||| % { gitalyctlSelector: gitalyctlSelector },
      colorMode='none',
      noValue='Not Configured'
    ),
    concurrencyByRepositoryType('projects'),
    concurrencyByRepositoryType('groups'),
    concurrencyByRepositoryType('snippets'),
  ], startRow=1101, cols=4)
)
.addPanel(
  row.new(title='gitalyctl logs'),
  gridPos={
    x: 0,
    y: 1200,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.timeSeries(
        title='Info Logs',
        description='How many info logs we have for gitalyctl',
        datasource='ops',
        query=|||
          count_over_time({namespace="gitalyctl", container="gitalyctl"} |= `info` [$__interval])
        |||,
        legendFormat='{{ storage }}'
      ),
      panel.timeSeries(
        title='Error Logs',
        description='How many error logs we have for gitalyctl',
        datasource='ops',
        query=|||
          count_over_time({namespace="gitalyctl", container="gitalyctl"} | json level="level" | level = `error` [$__interval])
        |||,
        legendFormat='{{ storage }}'
      ),
    ],
    startRow=1201,
    cols=2,
  )
)
.addPanel(
  row.new(title='gitalyctl projects repositories'),
  gridPos={
    x: 0,
    y: 1300,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(repsitoryTypeRates('projects'), startRow=1301, cols=4)
)
.addPanel(
  row.new(title='gitalyctl groups repositories'),
  gridPos={
    x: 0,
    y: 1400,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(repsitoryTypeRates('groups'), startRow=1401, cols=4)
)
.addPanel(
  row.new(title='gitalyctl snippets repositories'),
  gridPos={
    x: 0,
    y: 1500,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(repsitoryTypeRates('snippets'), startRow=1501, cols=4)
)
.addPanel(
  row.new(title='USE method gitalyctl deployment'),
  gridPos={
    x: 0,
    y: 1600,
    w: 24,
    h: 1,
  }
)
.addPanels(
  layout.grid(
    [
      panel.multiTimeSeries(
        title='CPU',
        queries=[
          {
            query: |||
              rate(container_cpu_usage_seconds_total{%(gitalyctlSelector)s}[$__rate_interval])
            ||| % { gitalyctlSelector: gitalyctlSelector },
            legendFormat: '{{ cpu }}',
          },
          {
            query: |||
              kube_pod_container_resource_limits{%(gitalyctlSelector)s, %(unit)s}
            ||| % { gitalyctlSelector: gitalyctlSelector, unit: selectors.serializeHash({ unit: 'core' }) },
            legendFormat: 'limit',
          },
          {
            query: |||
              kube_pod_container_resource_requests{%(gitalyctlSelector)s, %(unit)s}
            ||| % { gitalyctlSelector: gitalyctlSelector, unit: selectors.serializeHash({ unit: 'core' }) },
            legendFormat: 'request',
          },
        ],
      ),
      panel.multiTimeSeries(
        title='Memory',
        queries=[
          {
            query: |||
              rate(container_memory_usage_bytes{%(gitalyctlSelector)s}[$__rate_interval])
            ||| % { gitalyctlSelector: gitalyctlSelector },
            legendFormat: 'current',
          },
          {
            query: |||
              kube_pod_container_resource_limits{%(gitalyctlSelector)s, %(unit)s}
            ||| % { gitalyctlSelector: gitalyctlSelector, unit: selectors.serializeHash({ unit: 'byte' }) },
            legendFormat: 'limit',
          },
          {
            query: |||
              kube_pod_container_resource_requests{%(gitalyctlSelector)s, %(unit)s}
            ||| % { gitalyctlSelector: gitalyctlSelector, unit: selectors.serializeHash({ unit: 'byte' }) },
            legendFormat: 'request',
          },
        ],
        format='bytes',
      ),
    ],
    startRow=1601,
    cols=2,
  )
)
.trailer()
