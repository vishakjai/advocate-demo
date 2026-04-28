#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 -m <prepare|update|publish> -b <pulp_base_url> -u <username> -p <password> [-r <rpm_signing_service>] [-d <deb_signing_service>] [-o <output_dir>] [-n <parallel>]"
  echo "       -r and -d are required for update mode."
  echo "       -d is required for publish mode."
  exit 1
}

REPO_DIR="repos"
MODE=""
PARALLEL=10

while getopts "m:b:r:d:u:p:o:n:" opt; do
  case "$opt" in
  m) MODE="$OPTARG" ;;
  b) PULP_BASE_URL="$OPTARG" ;;
  r) RPM_SIGNING_SERVICE="$OPTARG" ;;
  d) DEB_SIGNING_SERVICE="$OPTARG" ;;
  u) PULP_USER="$OPTARG" ;;
  p) PULP_PASS="$OPTARG" ;;
  o) REPO_DIR="$OPTARG" ;;
  n) PARALLEL="$OPTARG" ;;
  *) usage ;;
  esac
done

PULP_BASE_URL="${PULP_BASE_URL%/}"

if [[ -z ${MODE:-} || -z ${PULP_BASE_URL:-} || -z ${PULP_USER:-} || -z ${PULP_PASS:-} ]]; then
  usage
fi

if [[ $MODE != "prepare" && $MODE != "update" && $MODE != "publish" ]]; then
  echo "Error: Mode must be 'prepare', 'update', or 'publish'."
  usage
fi

if [[ $MODE == "update" && (-z ${RPM_SIGNING_SERVICE:-} || -z ${DEB_SIGNING_SERVICE:-}) ]]; then
  echo "Error: -r and -d are required for update mode."
  usage
fi

if [[ $MODE == "publish" && -z ${DEB_SIGNING_SERVICE:-} ]]; then
  echo "Error: -d is required for publish mode."
  usage
fi

# Repo dir must exist for update/publish, but not for prepare (it creates it)
if [[ $MODE != "prepare" && ! -d $REPO_DIR ]]; then
  echo "Error: Repo directory '$REPO_DIR' not found. Run prepare first."
  exit 1
fi

if [[ $MODE == "update" ]]; then
  echo "Looking up RPM signing service href for '$RPM_SIGNING_SERVICE'..."
  RPM_SIGNING_SERVICE_HREF=$(pulp --username "$PULP_USER" --password "$PULP_PASS" --base-url "$PULP_BASE_URL" signing-service list --name "$RPM_SIGNING_SERVICE" | jq -r '.[0].pulp_href // empty')
  if [[ -z $RPM_SIGNING_SERVICE_HREF ]]; then
    echo "Error: RPM signing service '$RPM_SIGNING_SERVICE' not found."
    exit 1
  fi
  echo "RPM signing service href: $RPM_SIGNING_SERVICE_HREF"

  echo "Looking up DEB signing service href for '$DEB_SIGNING_SERVICE'..."
  DEB_SIGNING_SERVICE_HREF=$(pulp --username "$PULP_USER" --password "$PULP_PASS" --base-url "$PULP_BASE_URL" signing-service list --name "$DEB_SIGNING_SERVICE" | jq -r '.[0].pulp_href // empty')
  if [[ -z $DEB_SIGNING_SERVICE_HREF ]]; then
    echo "Error: DEB signing service '$DEB_SIGNING_SERVICE' not found."
    exit 1
  fi
  echo "DEB signing service href: $DEB_SIGNING_SERVICE_HREF"
fi

echo "Mode: $MODE"

# ---------------------------------------------------------------------------
# prepare: fetch all RPM + DEB repos from Pulp, write one file per repo
# ---------------------------------------------------------------------------
prepare_repos() {
  local rpm_tmp deb_tmp
  rpm_tmp=$(mktemp)
  deb_tmp=$(mktemp)
  trap 'rm -f "$rpm_tmp" "$deb_tmp"' RETURN

  echo ""
  echo "=== Preparing repository files ==="

  echo -n "Fetching RPM repositories ... "
  pulp --username "$PULP_USER" --password "$PULP_PASS" --base-url "$PULP_BASE_URL" rpm repository list --limit 5000 2>/dev/null |
    grep -m1 '^\[' >"$rpm_tmp"
  local rpm_count
  rpm_count=$(jq 'length' "$rpm_tmp")
  echo "$rpm_count repos found"

  echo -n "Fetching DEB repositories ... "
  pulp --username "$PULP_USER" --password "$PULP_PASS" --base-url "$PULP_BASE_URL" deb repository list --limit 5000 2>/dev/null |
    grep -m1 '^\[' >"$deb_tmp"
  local deb_count
  deb_count=$(jq 'length' "$deb_tmp")
  echo "$deb_count repos found"

  echo "Writing repo files to $REPO_DIR/ ..."
  mkdir -p "$REPO_DIR/rpm" "$REPO_DIR/deb"

  jq -r '.[] | "\(.name)\t\(.pulp_href)"' "$rpm_tmp" | while IFS=$'\t' read -r name href; do
    cat >"$REPO_DIR/rpm/${name}.yaml" <<EOF
name: "$name"
href: "$href"
updated: false
published: false
EOF
  done

  jq -r '.[] | "\(.name)\t\(.pulp_href)"' "$deb_tmp" | while IFS=$'\t' read -r name href; do
    cat >"$REPO_DIR/deb/${name}.yaml" <<EOF
name: "$name"
href: "$href"
updated: false
published: false
EOF
  done

  echo "Done. $rpm_count RPM files written to $REPO_DIR/rpm/"
  echo "      $deb_count DEB files written to $REPO_DIR/deb/"
}

# ---------------------------------------------------------------------------
# mark_repo_field: flip a field from false to true in a single repo file
# ---------------------------------------------------------------------------
mark_repo_field() {
  local file="$1"
  local field="$2"
  if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "s/^${field}: false$/${field}: true/" "$file"
  else
    sed -i "s/^${field}: false$/${field}: true/" "$file"
  fi
}
export -f mark_repo_field

# ---------------------------------------------------------------------------
# process_rpm_repos: update or publish all RPM repos in parallel
# ---------------------------------------------------------------------------
process_rpm_repos() {
  echo ""
  echo "=== ${MODE^} RPM repositories ==="

  local status_field
  [[ $MODE == "update" ]] && status_field="updated" || status_field="published"

  export PULP_USER PULP_PASS PULP_BASE_URL MODE RPM_SIGNING_SERVICE status_field

  _work_rpm() {
    local file="$1"
    local name href status_value logfile
    name=$(grep '^name:' "$file" | sed 's/^name: "\(.*\)"/\1/')
    href=$(grep '^href:' "$file" | sed 's/^href: "\(.*\)"/\1/')
    status_value=$(grep "^${status_field}:" "$file" | awk '{print $2}')
    logfile="${file%.yaml}.log"

    if [[ $status_value == "true" ]]; then
      echo "SKIP $file $name"
      return
    fi

    if [[ $MODE == "update" ]]; then
      if pulp --username "$PULP_USER" --password "$PULP_PASS" --base-url "$PULP_BASE_URL" \
        rpm repository update --href "$href" --metadata-signing-service "$RPM_SIGNING_SERVICE" >"$logfile" 2>&1; then
        rm -f "$logfile"
        echo "OK $file $name"
      else
        echo "FAILED $file $name"
      fi
    else
      if pulp --username "$PULP_USER" --password "$PULP_PASS" --base-url "$PULP_BASE_URL" \
        rpm publication create --repository "$href" >"$logfile" 2>&1; then
        rm -f "$logfile"
        echo "OK $file $name"
      else
        echo "FAILED $file $name"
      fi
    fi
  }
  export -f _work_rpm

  while IFS=' ' read -r status file name; do
    case "$status" in
    SKIP) echo "SKIP (already ${MODE}d): $name" ;;
    OK)
      mark_repo_field "$file" "$status_field"
      echo "OK: $name"
      ;;
    FAILED) echo "FAILED: $name (see ${file%.yaml}.log)" ;;
    esac
  done < <(printf '%s\n' "$REPO_DIR"/rpm/*.yaml | xargs -P "$PARALLEL" -I{} bash -c '_work_rpm "$@"' _ {})
}

# ---------------------------------------------------------------------------
# process_deb_repos: update or publish all DEB repos in parallel
# ---------------------------------------------------------------------------
process_deb_repos() {
  echo ""
  echo "=== ${MODE^} DEB repositories ==="

  local status_field
  [[ $MODE == "update" ]] && status_field="updated" || status_field="published"

  export PULP_USER PULP_PASS PULP_BASE_URL MODE DEB_SIGNING_SERVICE DEB_SIGNING_SERVICE_HREF status_field

  _work_deb() {
    local file="$1"
    local name href status_value logfile
    name=$(grep '^name:' "$file" | sed 's/^name: "\(.*\)"/\1/')
    href=$(grep '^href:' "$file" | sed 's/^href: "\(.*\)"/\1/')
    status_value=$(grep "^${status_field}:" "$file" | awk '{print $2}')
    logfile="${file%.yaml}.log"

    if [[ $status_value == "true" ]]; then
      echo "SKIP $file $name"
      return
    fi

    if [[ $MODE == "update" ]]; then
      local http_code response_body
      response_body=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
        -X PATCH \
        -H "Content-Type: application/json" \
        -u "${PULP_USER}:${PULP_PASS}" \
        -d "{\"signing_service\": \"${DEB_SIGNING_SERVICE_HREF}\"}" \
        "${PULP_BASE_URL}${href}")
      http_code=$(echo "$response_body" | grep 'HTTP_CODE:' | cut -d: -f2)
      if [[ $http_code =~ ^2 ]]; then
        rm -f "$logfile"
        echo "OK $file $name"
      else
        echo "$response_body" >"$logfile"
        echo "FAILED $file $name"
      fi
    else
      if pulp --username "$PULP_USER" --password "$PULP_PASS" --base-url "$PULP_BASE_URL" \
        deb publication create --repository "$name" --signing-service "$DEB_SIGNING_SERVICE" >"$logfile" 2>&1; then
        rm -f "$logfile"
        echo "OK $file $name"
      else
        echo "FAILED $file $name"
      fi
    fi
  }
  export -f _work_deb

  while IFS=' ' read -r status file name; do
    case "$status" in
    SKIP) echo "SKIP (already ${MODE}d): $name" ;;
    OK)
      mark_repo_field "$file" "$status_field"
      echo "OK: $name"
      ;;
    FAILED) echo "FAILED: $name (see ${file%.yaml}.log)" ;;
    esac
  done < <(printf '%s\n' "$REPO_DIR"/deb/*.yaml | xargs -P "$PARALLEL" -I{} bash -c '_work_deb "$@"' _ {})
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
if [[ $MODE == "prepare" ]]; then
  prepare_repos
  exit 0
fi

process_rpm_repos
process_deb_repos

echo ""
echo "Done."
