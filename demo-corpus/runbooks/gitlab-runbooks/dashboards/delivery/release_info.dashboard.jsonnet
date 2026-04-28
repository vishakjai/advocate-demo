local grafana = import 'github.com/grafana/grafonnet-lib/grafonnet/grafana.libsonnet';
local basic = import 'grafana/basic.libsonnet';
local layout = import 'grafana/layout.libsonnet';
local promQuery = import 'grafana/prom_query.libsonnet';
local row = grafana.row;
local mimirHelper = import 'services/lib/mimir-helpers.libsonnet';

// Monthly Release Information panels

local monthlyReleaseStatusQuery = 'delivery_release_monthly_status';

local monthlyReleaseInfoTextPanel =
  basic.text(
    title='',
    content=|||
      # Upcoming Monthly Release

      GitLab releases a new self-managed release on the third Thursday of every month.

      This release is a semver versioned package containing changes from many successful deployments on GitLab.com.

      The following panels contain information about the upcoming monthly release.

      Links:
      - [Monthly release schedule](https://about.gitlab.com/releases/)
      - [Overview of the process](https://handbook.gitlab.com/handbook/engineering/deployments-and-releases/)
      - [How can I determine if my MR will make it into the monthly release](https://handbook.gitlab.com/handbook/engineering/releases/#how-can-i-determine-if-my-merge-request-will-make-it-into-the-monthly-release)

      For inquiries about the monthly release, please ask in the [`#releases` slack channel](https://gitlab.enterprise.slack.com/archives/C0XM5UU6B).
    |||,
  );

local monthlyReleaseStatusTextPanel =
  basic.text(
    title='',
    content=|||
      # Release Status

      The panel below shows the current status of the upcoming monthly release.

      The following are what the statuses signify for engineers:

      * Open: Any commit that reached production is expected to be released with the upcoming monthly release. Barring any issues, MRs merged and deployed by 16:00 UTC of the day before the due date for tagging Release Candidate (RC) are guaranteed to be included.
      * Closed: The stable branch has been created, and the release candidate has been tagged. No more features will be included in the release.
    |||,
  );

local monthlyReleaseDateAndVersionStatPanel =
  basic.statPanel(
    title='',
    panelTitle='',
    description='This is the upcoming monthly release version that will be published on the next third Thursday of the month.',
    query=monthlyReleaseStatusQuery,
    colorMode='thresholds',
    fields='/.*/',
    format='table',
    graphMode='area',
    instant=false,
    justifyMode='center',
    color=[
      { color: 'white', value: null },
    ],
    transformations=[
      {
        id: 'groupBy',
        options: {
          fields: {
            release_date: {
              aggregations: [],
              operation: 'groupby',
            },
            version: {
              aggregations: [],
              operation: 'groupby',
            },
          },
        },
      },
      {
        id: 'reduce',
        options: {
          reducers: [
            'lastNotNull',
          ],
          includeTimeField: false,
          mode: 'reduceFields',
        },
      },
      {
        id: 'organize',
        options: {
          excludeByName: {},
          includeByName: {},
          indexByName: {
            release_date: 1,
            version: 0,
          },
          renameByName: {},
        },
      },
    ],
  ) + {
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'release_date',
          },
          properties: [
            {
              id: 'displayName',
              value: 'Release Date',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'version',
          },
          properties: [
            {
              id: 'displayName',
              value: 'Version',
            },
          ],
        },
      ],
    },
  };

local monthlyReleaseDuedateAndStatusStatPanel =
  basic.statPanel(
    title='',
    panelTitle='',
    description='This is the cutoff date for the features to be included in the upcoming monthly release version.',
    query=monthlyReleaseStatusQuery,
    colorMode='value',
    fields='/.*/',
    format='table',
    graphMode='area',
    instant=false,
    justifyMode='center',
    color=[
      { color: 'text', value: null },
      { color: 'green', value: 1 },
      { color: 'red', value: 2 },
    ],
    noValue='Open',
    mappings=[
      {
        id: 0,
        type: 1,
        value: '1',
        text: 'Open',
      },
      {
        id: 1,
        type: 1,
        value: '2',
        text: 'Closed',
      },
    ],
    transformations=[
      {
        id: 'groupBy',
        options: {
          fields: {
            due_date: {
              aggregations: [],
              operation: 'groupby',
            },
            Value: {
              aggregations: [],
              operation: 'groupby',
            },
          },
        },
      },
      {
        id: 'reduce',
        options: {
          reducers: [
            'lastNotNull',
          ],
          includeTimeField: false,
          mode: 'reduceFields',
        },
      },
      {
        id: 'organize',
        options: {
          excludeByName: {},
          includeByName: {},
          indexByName: {
            due_date: 0,
            Value: 0,
          },
          renameByName: {},
        },
      },
    ],
  ) + {
    fieldConfig+: {
      overrides: [
        {
          matcher: {
            id: 'byName',
            options: 'due_date',
          },
          properties: [
            {
              id: 'displayName',
              value: 'Due Date for tagging RC',
            },
          ],
        },
        {
          matcher: {
            id: 'byName',
            options: 'Value',
          },
          properties: [
            {
              id: 'displayName',
              value: 'Current Release Status',
            },
          ],
        },
      ],
    },
  };

local monthlyReleaseStatusStatPanel =
  basic.statPanel(
    title='',
    panelTitle='',
    description='Current status of the monthly release. More information about the statuses in the text panel above.',
    query=monthlyReleaseStatusQuery,
    colorMode='value',
    textMode='value',
    fields='/^Value$/',
    format='table',
    graphMode='area',
    instant=false,
    noValue=null,
    mappings=[
      {
        id: 0,
        type: 1,
        value: '1',
        text: 'Accepting deployed merge requests',
      },
      {
        id: 1,
        type: 1,
        value: '2',
        text: 'Not accepting new features',
      },
    ],
    color=[
      { color: 'green', value: null },
      { color: 'red', value: 2 },
    ],
    transformations=[
      {
        id: 'groupBy',
        options: {
          fields: {
            Value: {
              aggregations: [],
              operation: 'groupby',
            },
            release_date: {
              aggregations: [],
              operation: 'groupby',
            },
          },
        },
      },
      {
        id: 'reduce',
        options: {
          reducers: [
            'lastNotNull',
          ],
          includeTimeField: false,
          mode: 'reduceFields',
        },
      },
    ],
  );

// Patch Release Information panels

local patchReleaseStatusQuery = 'delivery_release_patch_status';

local patchReleaseInfoTextPanel =
  basic.text(
    title='',
    content=|||
      # Upcoming Patch Release

      Patch releases include bug and security fixes based on the [Maintenance Policy](https://docs.gitlab.com/ee/policy/maintenance.html), they are scheduled twice a month on the Wednesday the week before and the Wednesday the week after the monthly minor release.

      The following panels contain information about the upcoming patch release.

      Links:
      - [Overview of the Patch Release Process](https://handbook.gitlab.com/handbook/engineering/releases/#patch-releases-overview)
      - [Maintenance Policy](https://docs.gitlab.com/ee/policy/maintenance.html)
      - [Currently maintained versions](https://docs.gitlab.com/policy/maintenance/#maintained-versions)
        - They will be different from the currently maintained versions when the active monthly release date is prior to the active patch release date.
      - [Process to include bug fixes](https://gitlab.com/gitlab-org/release/docs/-/blob/master/general/patch/engineers.md)
        - Maintainers can now merge bug fixes and performance improvements to the current and last two releases without needing an exception request. More info on the [announcement issue](https://gitlab.com/gitlab-com/gl-infra/delivery/-/issues/21474).
      - [Process to include security fixes](https://gitlab.com/gitlab-org/release/docs/-/blob/master/general/security/engineer.md)
      - [Backporting to older releases](https://docs.gitlab.com/ee/policy/maintenance.html#backporting-to-older-releases)
      - [Security Tracking Issue](https://gitlab.com/gitlab-org/gitlab/-/issues/?sort=created_date&state=opened&label_name%5B%5D=upcoming%20security%20release&first_page_size=20)

      For inquiries about the patch release, please ask in the [`#releases` slack channel](https://gitlab.enterprise.slack.com/archives/C0XM5UU6B).
    |||,
  );

local patchReleaseStatusTextPanel =
  basic.text(
    title='',
    content=|||
      # Release Status

      The panel below shows the current status of the upcoming patch release.

      The following are what the statuses signify for engineers:

      * Open: Bug fixes and MRs associated with security issues labelled `security-target` are expected to be included in the next patch release.
      * Warning: Set 3 business days before the patch release due date, signals that teams should get bug and security fixes ready to merge. **Security merge requests should be approved, with green pipelines and ready to be merged 2 working days before the patch release due date, by the start of EMEA day**
      * Closed: Default branch MRs have been merged, no further bug or security fixes will be included.
    |||,
  );

local patchReleaseVersionStatPanel =
  basic.statPanel(
    title='',
    panelTitle='Release Versions',
    description='These are the upcoming patch release versions (stable version + 2 backport versions) that will be published. They will be different from the currently maintained versions when the active monthly release date is prior to the active patch release date.',
    query=patchReleaseStatusQuery,
    colorMode='thresholds',
    fields='/^versions$/',
    format='table',
    graphMode='area',
    instant=false,
    color=[
      { color: 'white', value: null },
    ],
    transformations=[
      {
        id: 'groupBy',
        options: {
          fields: {
            Value: {
              aggregations: [],
              operation: 'groupby',
            },
            release_date: {
              aggregations: [],
              operation: 'groupby',
            },
            versions: {
              aggregations: [],
              operation: 'groupby',
            },
          },
        },
      },
      {
        id: 'reduce',
        options: {
          reducers: [
            'lastNotNull',
          ],
          includeTimeField: false,
          mode: 'reduceFields',
        },
      },
    ],
  );

local patchReleaseDateStatPanel =
  basic.statPanel(
    title='',
    panelTitle='Expected Release Date',
    description="This is the best-effort release date for the upcoming patch release, and might be subject to change. A good place to confirm is the tracking issue's due date.",
    query=patchReleaseStatusQuery,
    colorMode='thresholds',
    fields='/^release_date$/',
    format='table',
    graphMode='area',
    instant=false,
    color=[
      { color: 'white', value: null },
    ],
    transformations=[
      {
        id: 'groupBy',
        options: {
          fields: {
            Value: {
              aggregations: [],
              operation: 'groupby',
            },
            release_date: {
              aggregations: [],
              operation: 'groupby',
            },
            versions: {
              aggregations: [],
              operation: 'groupby',
            },
          },
        },
      },
      {
        id: 'reduce',
        options: {
          reducers: [
            'lastNotNull',
          ],
          includeTimeField: false,
          mode: 'reduceFields',
        },
      },
    ],
  );

local patchReleaseStatusStatPanel =
  basic.statPanel(
    title='',
    panelTitle='Current Release Status',
    description='Current status of the patch release. More information about the statuses in the text panel above.',
    query=patchReleaseStatusQuery,
    colorMode='value',
    fields='/^Value$/',
    format='table',
    graphMode='area',
    instant=false,
    noValue='Open',
    mappings=[
      {
        id: 0,
        type: 1,
        value: '1',
        text: 'Open',
      },
      {
        id: 1,
        type: 1,
        value: '2',
        text: 'Warning',
      },
      {
        id: 2,
        type: 1,
        value: '3',
        text: 'Closed',
      },
    ],
    color=[
      { color: 'green', value: null },
      { color: 'yellow', value: 2 },
      { color: 'red', value: 3 },
    ],
    transformations=[
      {
        id: 'groupBy',
        options: {
          fields: {
            Value: {
              aggregations: [],
              operation: 'groupby',
            },
            release_date: {
              aggregations: [],
              operation: 'groupby',
            },
            versions: {
              aggregations: [],
              operation: 'groupby',
            },
          },
        },
      },
      {
        id: 'reduce',
        options: {
          reducers: [
            'lastNotNull',
          ],
          includeTimeField: false,
          mode: 'reduceFields',
        },
      },
    ],
  );

basic.dashboard(
  'Release Information',
  tags=['release'],
  editable=true,
  time_from='now-24h',
  time_to='now',
  includeStandardEnvironmentAnnotations=false,
  includeEnvironmentTemplate=false,
  defaultDatasource=mimirHelper.mimirDatasource('gitlab-ops'),
)

.addPanel(
  row.new(title='Monthly Release Information'),
  gridPos={ x: 0, y: 0, w: 24, h: 1 },
)
.addPanel(
  monthlyReleaseInfoTextPanel, gridPos={ x: 0, y: 1, w: 16, h: 10 }
)
.addPanel(
  monthlyReleaseStatusTextPanel, gridPos={ x: 16, y: 1, w: 8, h: 10 }
)
.addPanel(
  monthlyReleaseDateAndVersionStatPanel, gridPos={ x: 0, y: 11, w: 8, h: 8 }
)
.addPanel(
  monthlyReleaseDuedateAndStatusStatPanel, gridPos={ x: 8, y: 11, w: 8, h: 8 }
)
.addPanel(
  monthlyReleaseStatusStatPanel, gridPos={ x: 16, y: 11, w: 8, h: 8 }
)
.addPanel(
  row.new(title='Patch Release Information'),
  gridPos={ x: 0, y: 19, w: 24, h: 1 },
)
.addPanel(
  patchReleaseInfoTextPanel, gridPos={ x: 0, y: 20, w: 16, h: 11 }
)
.addPanel(
  patchReleaseStatusTextPanel, gridPos={ x: 16, y: 20, w: 8, h: 11 }
)
.addPanel(
  patchReleaseVersionStatPanel, gridPos={ x: 0, y: 31, w: 8, h: 8 }
)
.addPanel(
  patchReleaseDateStatPanel, gridPos={ x: 8, y: 31, w: 8, h: 8 }
)
.addPanel(
  patchReleaseStatusStatPanel, gridPos={ x: 16, y: 31, w: 8, h: 8 }
)
.trailer()
