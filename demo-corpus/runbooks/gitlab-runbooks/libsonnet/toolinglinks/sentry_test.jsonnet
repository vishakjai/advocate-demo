local sentry = import './sentry.libsonnet';
local test = import 'github.com/yugui/jsonnetunit/jsonnetunit/test.libsonnet';

test.suite({
  testSentryPlain: {
    actual: sentry.sentry(3, variables=['environment', 'stage'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/releases/?project=3&environment=${environment}',
      },
      {
        title: '🐞 Sentry issues',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/issues/?project=3&environment=${environment}&query=stage%3A${stage}',
      },
    ],
  },
  testSentryType: {
    actual: sentry.sentry(3, type='sidekiq', variables=['environment', 'stage'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/releases/?project=3&environment=${environment}',
      },
      {
        title: '🐞 Sentry sidekiq issues',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/issues/?project=3&environment=${environment}&query=stage%3A${stage}+type%3Asidekiq',
      },
    ],
  },
  testSentryFeatureCatagories: {
    actual: sentry.sentry(12, featureCategories=['subgroups', 'users'], variables=['environment', 'stage'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/releases/?project=12&environment=${environment}',
      },
      {
        title: '🐞 Sentry issues: subgroups',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/issues/?project=12&environment=${environment}&query=feature_category%3Asubgroups+stage%3A${stage}',
      },
      {
        title: '🐞 Sentry issues: users',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/issues/?project=12&environment=${environment}&query=feature_category%3Ausers+stage%3A${stage}',
      },
    ],
  },
  testSentryTypeAndFeatureCatagories: {
    actual: sentry.sentry(7, type='web', featureCategories=['subgroups', 'users'], variables=['environment', 'stage'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/releases/?project=7&environment=${environment}',
      },
      {
        title: '🐞 Sentry web issues: subgroups',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/issues/?project=7&environment=${environment}&query=feature_category%3Asubgroups+stage%3A${stage}+type%3Aweb',
      },
      {
        title: '🐞 Sentry web issues: users',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/issues/?project=7&environment=${environment}&query=feature_category%3Ausers+stage%3A${stage}+type%3Aweb',
      },
    ],
  },
  testSentryTypeAndFeatureCatagoriesDefaultVariables: {
    actual: sentry.sentry(8, type='web', featureCategories=['subgroups', 'users'])(options={}),
    expect: [
      {
        title: '🐞 Sentry Releases',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/releases/?project=8&environment=${environment}',
      },
      {
        title: '🐞 Sentry web issues: subgroups',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/issues/?project=8&environment=${environment}&query=feature_category%3Asubgroups+type%3Aweb',
      },
      {
        title: '🐞 Sentry web issues: users',
        url: 'https://new-sentry.gitlab.net/organizations/gitlab/issues/?project=8&environment=${environment}&query=feature_category%3Ausers+type%3Aweb',
      },
    ],
  },
})
