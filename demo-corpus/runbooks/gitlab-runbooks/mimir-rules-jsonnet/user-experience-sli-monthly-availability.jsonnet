local userExperienceSlIs = import 'stage-groups/user-experience-sli/queries.libsonnet';

local aggregationLabels = ['env', 'stage_group', 'product_stage', 'user_experience_id'];
local selector = {
  // Filtering out staging and canary makes these queries a tiny bit cheaper
  stage: 'main',
  env: 'gprd',
};

local rules = {
  groups: [
    local queries = userExperienceSlIs.init(range);
    {
      name: '%s User Experience SLI monthly availability ratio' % [range],
      // Using a long interval, because aggregating a month worth of data is not cheap,
      // but it also doesn't change fast.
      // Make sure to query these with `last_over_time([ > 30m])`
      interval: '30m',
      rules: [{
        record: 'gitlab:user_experience_sli:stage_groups:availability:ratio_%s' % [range],
        expr: queries.combinedRatio(selector, aggregationLabels),
      }],
    }
    for range in ['7d', '28d']
  ],
};

// This is filtered to only record for gprd, no need to separatly record for each environment
{
  'gitlab-gprd/user-experience-sli-stage-group-monthly-availability.yml': std.manifestYamlDoc(rules),
}
