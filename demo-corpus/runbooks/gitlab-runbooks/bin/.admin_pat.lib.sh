#!/usr/bin/env bash

###################################################
# Asks the user to create an admin PAT if one has not
# already been created
#
# Note:
#   It is the intention that this script asks for the admin
#   token on every invocation to discourage storing an admin
#   token on disk
###################################################
admin_pat() {
  local pass
  if [[ -n $pat ]]; then
    echo "$pat"
    return
  fi

  local token_url
  token_url="https://$(gitlab_host)/-/profile/personal_access_tokens"

  echo_err "This script requires an personal access token with admin API access."
  echo_err "Create a new one by:"
  echo_err " - Logging into GitLab with an admin account"
  echo_err " - Visit $token_url"
  echo_err " - Create a new token by selecting 'Add a new token' with API access"
  echo_err ""
  echo -n "enter token value: " >&2
  read -rs pass
  echo_err ""
  echo_err ""
  echo "$pass"
}
