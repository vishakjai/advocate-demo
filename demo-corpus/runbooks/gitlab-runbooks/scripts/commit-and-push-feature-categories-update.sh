#!/bin/bash -x

if [ -z "$UPDATE_FEATURE_CATEGORIES_GITLAB_TOKEN" ]; then
  echo "UPDATE_FEATURE_CATEGORIES_GITLAB_TOKEN must be set"
  exit 1
fi

current_date="$(date +'%Y-%m-%d')"
branch_name="update-feature-categories-${current_date}"
runbooks_origin=https://oauth2:${UPDATE_FEATURE_CATEGORIES_GITLAB_TOKEN}@gitlab.com/gitlab-com/${CI_PROJECT_NAME}.git
mr_title="Update feature categories ${current_date}"
mr_description="Update feature categories to ${current_date}.\n1. Please check the mapping on [stage-group-mapping-crossover.jsonnet](https://gitlab.com/gitlab-com/runbooks/-/blob/master/services/stage-group-mapping-crossover.jsonnet) to make sure old categories are mapped to new ones. The history of updates can be found on [stages.yml](https://gitlab.com/gitlab-com/www-gitlab-com/-/blob/master/data/stages.yml).\n1. Run \`make generate\` again.\n\nIf you would like to improve the script that generated this MR, please check https://gitlab.com/gitlab-com/runbooks/-/blob/master/scripts/commit-and-push-feature-categories-update.sh\n\n/reviewer @gitlab-org/scalability/observability"

git remote add runbooks_auth_origin "${runbooks_origin}"
git checkout -b "${branch_name}"

if [ -n "$FORCE_MAKE_GENERATE" ]; then
  make update-feature-categories
else
  ./scripts/update_stage_groups_feature_categories.rb
fi

if [ -z "$(git status --untracked-files=no --porcelain)" ]; then
  echo "No changes to commit. ✅"
  exit 0
fi

git add .
git commit -m "chore: ${mr_title}"
echo "Pushing to $runbooks_origin..."
git push --force-with-lease \
  -u runbooks_auth_origin \
  -o merge_request.create \
  -o merge_request.target=master \
  -o merge_request.remove_source_branch \
  -o merge_request.title="${mr_title}" \
  -o merge_request.description="${mr_description}" \
  -o merge_request.label="type::maintenance" \
  -o merge_request.label="maintenance::refactor" \
  -o merge_request.label="group::scalability" \
  -o merge_request.label="team::Scalability-Observability" \
  "${branch_name}"
