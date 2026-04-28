#!/usr/bin/env bash
# vim: ai:ts=2:sw=2:expandtab

set -euo pipefail
# Fail on subshells failing, dashboards are generated in subshells
# But not on macOS, because that ships with an older version of bash
# that does not support this shell option yet
(shopt -p | grep inherit_errexit >/dev/null) && shopt -s inherit_errexit

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

source "grafana-tools.lib.sh"

usage() {
  cat <<-EOF
  Usage $0 [Dh] path-to-file.dashboard.jsonnet

  DESCRIPTION
    This script generates dashboards and uploads
    them to the playground folder on dashboards.gitlab.net

    GRAFANA_API_TOKEN must be set in the environment

    Read dashboards/README.md for more details

  FLAGS
    -D  run in Dry-run
    -h  help

EOF
}

while getopts ":Dh" o; do
  case "${o}" in
  D)
    dry_run="true"
    ;;
  h)
    usage
    exit 0
    ;;
  *) ;;

  esac
done

shift $((OPTIND - 1))

if [[ $# != 1 ]]; then
  usage
  exit 0
fi

dry_run=${dry_run:-}

prepare

dashboard_file=$1

if [[ -n $dry_run ]]; then
  generate_dashboards_for_file "${dashboard_file}"
  exit 0
else
  if command -v op; then
    op signin -f
    GRAFANA_API_TOKEN=$(op read "op://Engineering/Grafana playground API token/Tokens/developer-playground-key API Key")
    export GRAFANA_API_TOKEN
  fi
  if [[ -z ${GRAFANA_API_TOKEN:-} ]]; then
    echo "You must set GRAFANA_API_TOKEN to use this script. Review the instructions in dashboards/README.md to details of how to obtain this token."
    exit 1
  fi

  dashboard_json=$(generate_dashboards_for_file "${dashboard_file}")
  if [[ -z $dashboard_json ]]; then
    echo 'Empty dashboard. Ignored!'
    exit 0
  fi

  # Check each dashboard before creating snapshots
  # For shared dashboards, this will be called once per dashboard
  echo "${dashboard_json}" | prepare_snapshot_requests | while IFS= read -r snapshot; do
    # Extract dashboard UID from the snapshot request
    dashboard_uid=$(echo "${snapshot}" | jq -r '.dashboard.uid // empty')
    if [[ -z $dashboard_uid ]]; then
      echo >&2 "Error: Could not determine dashboard UID from generated dashboard."
      exit 1
    fi

    # Check if dashboard exists in Grafana before attempting to create snapshot
    if ! dashboard_exists "${dashboard_uid}"; then
      dashboard_title=$(echo "${snapshot}" | jq -r '.dashboard.title // "Unknown"')
      echo >&2 ""
      echo >&2 "Error: Dashboard '${dashboard_title}' (UID: '${dashboard_uid}') does not exist in Grafana."
      echo >&2 ""
      echo >&2 "Snapshots can only be created for dashboards that have already been installed into Grafana."
      echo >&2 "For entirely new dashboards, consider merging a basic dashboard first."
      echo >&2 ""
      echo >&2 "See dashboards/README.md for more details."
      echo >&2 ""
      exit 1
    fi
    # Use http1.1 and gzip compression to workaround unexplainable random errors that
    # occur when uploading some dashboards
    if ! response=$(echo "${snapshot}" | call_grafana_api https://dashboards.gitlab.net/api/snapshots -d @-); then
      # If we get a 403 error after confirming the dashboard exists, provide additional context
      # Note: call_grafana_api outputs detailed error info to stderr when it fails
      echo >&2 ""
      echo >&2 "Error: Received 403 Forbidden when creating snapshot."
      echo >&2 "The dashboard exists, but the API token may not have permissions to create snapshots."
      echo >&2 "Please verify the token has the correct permissions."
      echo >&2 ""
    else
      url=$(echo "${response}" | jq -r '.url')
      title=$(echo "${snapshot}" | jq -r '.dashboard.title')
      # Extract default environment from dashboard template variables
      default_env=$(echo "${snapshot}" | jq -r '(.dashboard.templating.list[] | select(.name=="environment") | .current.value) // "gprd"')
      default_ds=$(echo "${snapshot}" | jq -r '.dashboard.templating.list[] | select(.name=="PROMETHEUS_DS") | .current.value // "mimir-gitlab-gprd"')
      echo "Installed ${url}?var-environment=${default_env}&orgId=1&var-PROMETHEUS_DS=${default_ds}&var-stage=main - ${title}"
    fi
  done
fi
