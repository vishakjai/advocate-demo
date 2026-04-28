{
  sync_id: 'incident-io/catalog',
  pipelines: [
    {
      sources: [
        {
          exec: { command: [
            'yq',
            'eval',
            '.services',
            'service-catalog.yml',
          ] },
        },
        {
          inline: {
            entries: [
              {
                name: 'Unknown',
                external_id: 'unknown',
              },
            ],
          },
        },
      ],
      outputs: [
        {
          name: 'Services',
          description: 'GitLab Services Catalog',
          type_name: 'Custom["Service"]',
          categories: ['service'],
          source: {
            name: '$.name',
            external_id: '$.name',
          },
          attributes: [
            {
              id: 'tier',
              name: 'Tier',
              type: 'String',
              source: '$.tier',
            },
            {
              id: 'description',
              name: 'Description',
              type: 'String',
              source: '$.friendly_name',
            },
            {
              id: 'teams',
              name: 'Teams',
              type: 'Custom["GitlabTeam"]',
              array: true,
              source: '$.teams',
            },
            {
              id: 'owner',
              name: 'Owner',
              type: 'Custom["GitlabTeam"]',
              source: '$.owner',
            },
          ],
        },
      ],
    },
    {
      sources: [{
        exec: { command: [
          'yq',
          'eval',
          '.teams',
          'teams.yml',
        ] },
      }],
      outputs: [
        {
          name: 'GitLab Teams',
          description: 'Teams from GitLab',
          type_name: 'Custom["GitlabTeam"]',
          categories: ['team'],
          source: {
            name: '$.name',
            external_id: '$.name',
          },
          attributes: [
            {
              id: 'maanger',
              name: 'Manager',
              type: 'User',
              source: '$.manager_slack',
            },
            {
              id: 'slack_user_group',
              name: 'Slack User Group',
              type: 'SlackUserGroup',
              source: '$.slack_group',
            },
            {
              id: '01K3V5531J8XKSF7P21G0E22FP',
              name: 'Members',
              type: 'User',
              array: true,
              path: [
                // Navigate from Slack user group...
                'slack_user_group',
                // ... to the Slack users in that group ...
                'users',
                // ... to the incident.io user associated with that Slack user
                'user',
              ],
            },
            {
              id: 'slack_channel',
              name: 'Team Slack Channel',
              type: 'SlackChannel',
              source: '$.slack_channel',
            },
            {
              id: 'slack_error_budget_channel',
              name: 'Slack Error Budget Channel',
              type: 'SlackChannel',
              source: '$.slack_error_budget_channel',
            },
            {
              id: 'product_stage_group',
              name: 'Product Stage Group',
              type: 'String',
              source: '$.product_stage_group',
            },
            {
              id: 'pagerduty_service',
              name: 'PagerDuty Service',
              type: 'PagerDutyService',
              source: '$.pagerduty_service',
            },
            {
              id: 'escalation_path',
              name: 'Escalation Path',
              type: 'EscalationPath',
              source: '$.escalation_path',
              array: false,
              schema_only: true,
            },
          ],
        },
      ],
    },
    {
      sources: [{
        exec: { command: [
          'yq',
          'eval',
          '.categories',
          'contributing-factors.yml',
        ] },
      }],
      outputs: [
        {
          name: 'Contributing Factor Categories',
          description: 'Categories of contributing factors',
          type_name: 'Custom["ContributingFactorCategories"]',
          source: {
            name: '$.name',
            external_id: '$.external_id',
          },
          attributes: [
            {
              id: 'name',
              name: 'Name',
              type: 'String',
              source: '$.name',
            },
            {
              id: 'external_id',
              name: 'ID',
              type: 'String',
              source: '$.external_id',
            },
          ],
        },
      ],
    },
    {
      sources: [
        {
          exec: { command: [
            'yq',
            'eval',
            '.factors',
            'contributing-factors.yml',
          ] },
        },
      ],
      outputs: [
        {
          name: 'Contributing Factors',
          description: 'Contributing factors that led to an incident',
          type_name: 'Custom["ContributingFactors"]',
          source: {
            name: '$.name',
            external_id: '$.external_id',
          },
          attributes: [
            {
              id: 'category',
              name: 'Category',
              type: 'Custom["ContributingFactorCategories"]',
              source: '$.category',
            },
          ],
        },
      ],
    },
  ],
}
