#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

# Check if sufficient arguments are provided
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 {alerts|rules|dashboards|all} MIXIN_DIR [OUTPUT_DIR]"
  exit 1
fi

if ! command -v mixtool >/dev/null; then
  cat <<-EOF
mixtool is not installed.

Please install using:

\`go install github.com/monitoring-mixins/mixtool/cmd/mixtool@main\`

For more information on mixins, consult the docs/monitoring/mixins.md readme in this repo.
EOF
  exit 1
fi

COMMAND=$1
MIXIN_DIR=$2
OUTPUT_DIR=${3:-"$SCRIPT_DIR/generated/$MIXIN_DIR"} # Use the provided output directory or default to "generated/$MIXIN_DIR"

# Create necessary directories
if [ "$#" -lt 3 ]; then
  mkdir -p "generated"
  mkdir -p "$OUTPUT_DIR"
fi

# Change to the specified MIXIN_DIR
cd "$MIXIN_DIR" || exit

jb install -q

# Common options for mixtool commands
COMMON_OPTS=(
  "-J" "vendor"
  "-J" "vendor/runbooks/libsonnet"
  "-J" "vendor/runbooks/reference-architectures/default-overrides"
  "-J" "overrides"
)

RULESET_DIR="$OUTPUT_DIR/prometheus-rules"
DASHBOARD_DIR="$OUTPUT_DIR/dashboards"

# Create necessary directories for mixtool
mkdir -p "$RULESET_DIR"
mkdir -p "$DASHBOARD_DIR"

# Execute the appropriate command
case $COMMAND in
alerts)
  mixtool generate alerts "${COMMON_OPTS[@]}" \
    -a "$RULESET_DIR/${MIXIN_DIR}.alerts.mixin.yml" \
    -y mixin.libsonnet
  ;;
rules)
  mixtool generate rules "${COMMON_OPTS[@]}" \
    -r "$RULESET_DIR/${MIXIN_DIR}.rules.mixin.yml" \
    -y mixin.libsonnet
  ;;
dashboards)
  mixtool generate dashboards "${COMMON_OPTS[@]}" \
    -d "$DASHBOARD_DIR" \
    mixin.libsonnet
  ;;
all)
  mixtool generate all "${COMMON_OPTS[@]}" \
    -d "$DASHBOARD_DIR" \
    -r "$RULESET_DIR/${MIXIN_DIR}.rules.mixin.yml" \
    -a "$RULESET_DIR/${MIXIN_DIR}.alerts.mixin.yml" \
    -y mixin.libsonnet
  ;;
*)
  echo "Invalid command. Use one of: alerts, rules, dashboards, all."
  exit 1
  ;;
esac
