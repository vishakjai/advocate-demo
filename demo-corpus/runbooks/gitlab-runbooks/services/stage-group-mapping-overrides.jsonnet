/*
This file should be updated manually.
This will allow merging two or more stage groups into a single one.
{
  "new_group": {
    name: "New Group Name",
    stage: "stage_key"
    merge_groups: ["group1_key", "group2_key"],
  }
}
*/
{
  gitaly: {
    name: 'Gitaly',
    stage: 'tenant_scale',
    merge_groups: ['gitaly', 'git'],
  },
  not_owned: {
    /* This is a special pseudo-stage group for the feature_category of `not_owned` and `unknown` */
    key: 'not_owned',
    name: 'not_owned',
    stage: 'not_owned',
    feature_categories: [
      'not_owned',
      'unknown',
    ],
    ignored_components: [],
  },
}
