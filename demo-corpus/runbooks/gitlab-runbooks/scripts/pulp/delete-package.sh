#!/usr/bin/env bash

# delete-package.sh
#
# Removes an RPM package from a Pulp repository and cleans up the orphaned
# content artifact from storage. Accepts partial package and repository name
# searches and disambiguates multiple matches with a helpful error.
#
# Usage:
#   delete-package.sh --package <search> --repository <search> [--profile <profile>] [--dry-run]
#
# Examples:
#   delete-package.sh --package gitlab-ee-18.9.1 --repository sles-12.5-x86_64
#   delete-package.sh --package gitlab-ee-18.9.1 --repository sles-12.5-x86_64 --profile ops
#   delete-package.sh --package gitlab-ee-18.9.1 --repository sles-12.5-x86_64 --dry-run
#
# See also: docs/pulp/delete-package.md

set -euo pipefail

PROFILE=""
DRY_RUN="false"
PACKAGE_SEARCH=""
REPOSITORY_SEARCH=""

function usage() {
  echo "Usage: ${0} --package <search> --repository <search> [--profile <profile>] [--dry-run]"
  echo ""
  echo "Examples:"
  echo "  ${0} --package gitlab-ee-18.9.1 --repository sles-12.5-x86_64"
  echo "  ${0} --package gitlab-ee-18.9.1 --repository sles-12.5-x86_64 --profile ops"
  echo "  ${0} --package gitlab-ee-18.9.1 --repository sles-12.5-x86_64 --dry-run"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
  --package)
    PACKAGE_SEARCH="${2}"
    shift 2
    ;;
  --repository)
    REPOSITORY_SEARCH="${2}"
    shift 2
    ;;
  --profile)
    PROFILE="${2}"
    shift 2
    ;;
  --dry-run)
    DRY_RUN="true"
    shift
    ;;
  *)
    usage
    ;;
  esac
done

if [[ -z ${PACKAGE_SEARCH} || -z ${REPOSITORY_SEARCH} ]]; then
  usage
fi

PULP_CMD="pulp"
if [[ -n ${PROFILE} ]]; then
  PULP_CMD="pulp --profile ${PROFILE}"
fi

echo "==> Step 1: Finding repository matching '${REPOSITORY_SEARCH}'..."
REPO_MATCHES=$(${PULP_CMD} repository list --name-contains "${REPOSITORY_SEARCH}" | jq '[.[].name]')
REPO_COUNT=$(echo "${REPO_MATCHES}" | jq 'length')

if [[ ${REPO_COUNT} -eq 0 ]]; then
  echo "ERROR: No repository matching '${REPOSITORY_SEARCH}' found."
  exit 1
elif [[ ${REPO_COUNT} -gt 1 ]]; then
  echo "ERROR: Multiple repositories match '${REPOSITORY_SEARCH}'. Please be more specific:"
  echo "${REPO_MATCHES}" | jq -r '.[]'
  exit 1
fi

REPOSITORY_NAME=$(echo "${REPO_MATCHES}" | jq -r '.[0]')
echo "    Found: ${REPOSITORY_NAME}"

echo "==> Step 2: Finding package matching '${PACKAGE_SEARCH}' in repository '${REPOSITORY_NAME}'..."
LATEST_VERSION=$(${PULP_CMD} rpm repository show --name "${REPOSITORY_NAME}" | jq -r '.latest_version_href')
PAGE_SIZE=100
OFFSET=0
MATCHES="[]"
MATCH_COUNT=0

while true; do
  PAGE_NUM=$((OFFSET / PAGE_SIZE + 1))
  echo "    Fetching page ${PAGE_NUM} (offset ${OFFSET})..."
  PAGE=$(${PULP_CMD} rpm content list --repository-version "${LATEST_VERSION}" --limit "${PAGE_SIZE}" --offset "${OFFSET}")
  PAGE_COUNT=$(echo "${PAGE}" | jq 'length')

  MATCHES=$(echo "${PAGE}" | jq --arg pkg "${PACKAGE_SEARCH}" '[.[] | select(.location_href | contains($pkg))]')
  MATCH_COUNT=$(echo "${MATCHES}" | jq 'length')

  # Stop if we found a match or exhausted all pages
  if [[ ${MATCH_COUNT} -gt 0 || ${PAGE_COUNT} -lt ${PAGE_SIZE} ]]; then
    break
  fi

  OFFSET=$((OFFSET + PAGE_SIZE))
  echo "    No match found on page ${PAGE_NUM}, continuing..."
done

if [[ ${MATCH_COUNT} -eq 0 ]]; then
  echo "ERROR: No package matching '${PACKAGE_SEARCH}' found in repository '${REPOSITORY_NAME}'."
  exit 1
elif [[ ${MATCH_COUNT} -gt 1 ]]; then
  echo "ERROR: Multiple packages match '${PACKAGE_SEARCH}' in repository '${REPOSITORY_NAME}'. Please be more specific:"
  echo "${MATCHES}" | jq -r '.[].location_href'
  exit 1
fi

HREF=$(echo "${MATCHES}" | jq -r '.[0].pulp_href')
PACKAGE_FILENAME=$(echo "${MATCHES}" | jq -r '.[0].location_href')
echo "    Found: ${PACKAGE_FILENAME} (${HREF})"

if [[ ${DRY_RUN} == "true" ]]; then
  echo ""
  echo "[Dry-run] Would remove package '${PACKAGE_FILENAME}' (${HREF}) from repository '${REPOSITORY_NAME}'."
  echo "[Dry-run] Would run orphan cleanup for ${HREF}."
  echo "[Dry-run] Re-run without --dry-run to apply changes."
  exit 0
fi

echo ""
echo "About to remove '${PACKAGE_FILENAME}' from '${REPOSITORY_NAME}' and delete it from storage."
read -r -p "Proceed? [y/N] " CONFIRM
if [[ ${CONFIRM} != "y" && ${CONFIRM} != "Y" ]]; then
  echo "Aborted."
  exit 0
fi
echo ""

echo "==> Step 3: Removing package from repository '${REPOSITORY_NAME}'..."
${PULP_CMD} rpm repository content remove \
  --repository "${REPOSITORY_NAME}" \
  --package-href "${HREF}"

echo "==> Step 4: Verifying package is removed from latest repository version..."
NEW_LATEST_VERSION=$(${PULP_CMD} rpm repository show --name "${REPOSITORY_NAME}" | jq -r '.latest_version_href')
FOUND=$(${PULP_CMD} rpm content list --repository-version "${NEW_LATEST_VERSION}" | jq -r --arg href "${HREF}" '.[] | select(.pulp_href == $href) | .pulp_href')

if [[ -n ${FOUND} ]]; then
  echo "ERROR: Package still found in latest repository version. Manual investigation required."
  exit 1
fi
echo "    Package successfully removed from latest repository version."

echo "==> Step 5: Cleaning up orphaned content artifact from storage..."
${PULP_CMD} orphan cleanup --content-hrefs "[\"${HREF}\"]"

echo ""
echo "Done. Package '${PACKAGE_FILENAME}' has been removed from '${REPOSITORY_NAME}' and deleted from storage."
