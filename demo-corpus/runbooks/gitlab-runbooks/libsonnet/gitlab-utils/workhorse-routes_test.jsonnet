local underTest = import './workhorse-routes.libsonnet';
local test = import 'test.libsonnet';

test.suite({
  testLiterals: {
    actual: underTest.escapeForLiterals(|||
      ^/([^/]+/){1,}[^/]+/uploads\z
      ^/-/
      ^/-/(readiness|liveness)$
      ^/-/cable\z
      ^/-/health$
      ^/.+\.git/git-receive-pack\z
      ^/.+\.git/git-upload-pack\z
      ^/.+\.git/gitlab-lfs/objects/([0-9a-f]{64})/([0-9]+)\z
      ^/.+\.git/info/refs\z
      ^/api/
      ^/api/graphql\z
      ^/api/v4/jobs/[0-9]+/artifacts\z
      ^/api/v4/jobs/request\z
      ^/api/v4/projects/[^/]+/packages/generic/
      ^/assets/
    |||),
    expect: [
      '^/([^/]+/){1,}[^/]+/uploads\\\\z',
      '^/-/',
      '^/-/(readiness|liveness)$',
      '^/-/cable\\\\z',
      '^/-/health$',
      '^/.+\\\\.git/git-receive-pack\\\\z',
      '^/.+\\\\.git/git-upload-pack\\\\z',
      '^/.+\\\\.git/gitlab-lfs/objects/([0-9a-f]{64})/([0-9]+)\\\\z',
      '^/.+\\\\.git/info/refs\\\\z',
      '^/api/',
      '^/api/graphql\\\\z',
      '^/api/v4/jobs/[0-9]+/artifacts\\\\z',
      '^/api/v4/jobs/request\\\\z',
      '^/api/v4/projects/[^/]+/packages/generic/',
      '^/assets/',
    ],
  },

})
