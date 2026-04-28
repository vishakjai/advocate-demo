local slis = std.parseYaml(importstr '../config/user_experience_slis/index.yml');

local ruleForSli(id, sli) = {
  record: 'gitlab:user_experience_sli:info',
  labels: {
    user_experience_id: id,
    urgency: sli.urgency,
  },
  expr: |||
    vector(1) * on() group_left(feature_category, stage_group, product_stage)
    gitlab:feature_category:stage_group:mapping{feature_category="%(feature_category)s"}
  ||| % { feature_category: sli.feature_category },
};

// This is filtered to only record for gprd, no need to separately record for each environment
{
  'gitlab-gprd/user-experience-sli-info.yml': std.manifestYamlDoc({
    groups: [{
      name: 'User Experience SLI absent',
      interval: '1m',
      rules: [
        ruleForSli(id, slis[id])
        for id in std.objectFields(slis)
      ],
    }],
  }),
}
