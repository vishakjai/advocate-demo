local toolingLinkDefinition = (import './tooling_link_definition.libsonnet').toolingLinkDefinition({ tool:: 'cloudflare' });

local defaultAccountId = '852e9d53d0f8adbd9205389356f2303d';

{
  cloudflare(
    accountId=defaultAccountId,
    zone='gitlab.com',
    host='gitlab.com'
  )::
    function(options)
      [
        toolingLinkDefinition({
          title: 'Cloudflare: ' + host,
          url: 'https://dash.cloudflare.com/%(accountId)s/%(zone)s/analytics/traffic?host=%(host)s&time-window=30' % {
            accountId: accountId,
            zone: zone,
            host: host,
          },
        }),
      ],

  cloudflareWorker:: {
    logs:: {
      historical(
        scriptName,
        accountId=defaultAccountId,
        // Environment is the environment in the CloudFlare account, typically "production".
        //
        // We typically have the GitLab "environment" denoted in the script-name.
        environment='production',
      )::
        function(options)
          [
            toolingLinkDefinition({
              title: '📖 Cloudflare Worker historical logs: ' + scriptName,
              url: 'https://dash.cloudflare.com/%(accountId)s/workers/services/view/%(scriptName)s/%(environment)s/observability/logs' % {
                scriptName: scriptName,
                accountId: accountId,
                environment: environment,
              },
            }),
            toolingLinkDefinition({
              title: '📖 Cloudflare Worker historical error logs: ' + scriptName,
              url: 'https://dash.cloudflare.com/%(accountId)s/workers/services/view/%(scriptName)s/%(environment)s/observability/logs?filters=%%5B%%7B%%22key%%22%%3A%%22%%24cloudflare.%%24metadata.error%%22%%2C%%22operation%%22%%3A%%22EXISTS%%22%%2C%%22type%%22%%3A%%22string%%22%%2C%%22id%%22%%3A%%22%%22%%7D%%5D' % {
                scriptName: scriptName,
                accountId: accountId,
                environment: environment,
              },
            }),
          ],

      live(
        scriptName,
        accountId=defaultAccountId,
        // Environment is the environment in the CloudFlare account, typically "production".
        //
        // We typically have the GitLab "environment" denoted in the script-name.
        environment='production',
      )::
        function(options)
          [
            toolingLinkDefinition({
              title: '📖 Cloudflare Worker live logs: ' + scriptName,
              url: 'https://dash.cloudflare.com/%(accountId)s/workers/services/live-logs/%(scriptName)s/%(environment)s' % {
                scriptName: scriptName,
                accountId: accountId,
                environment: environment,
              },
            }),
          ],
    },
    observability:: {
      visualization(
        title,
        url,
      )::
        function(options)
          [
            toolingLinkDefinition({
              title: '📊 Cloudflare Worker ' + title,
              url: url,
            }),
          ],
    },
    metrics:: {
      view(
        scriptName,
        accountId=defaultAccountId,
        // Environment is the environment in the CloudFlare account, typically "production".
        //
        // We typically have the GitLab "environment" denoted in the script-name.
        environment='production',
      )::
        function(options)
          [
            toolingLinkDefinition({
              title: '📊 Cloudflare Worker metrics: ' + scriptName,
              url: 'https://dash.cloudflare.com/%(accountId)s/workers/services/view/%(scriptName)s/%(environment)s/metrics' % {
                scriptName: scriptName,
                accountId: accountId,
                environment: environment,
              },
            }),
          ],
    },
  },
}
