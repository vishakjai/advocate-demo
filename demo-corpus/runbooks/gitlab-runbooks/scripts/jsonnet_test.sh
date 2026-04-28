#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

find_tests() {
  if [ -z "$1" ]; then
    find "$REPO_DIR" -name '*_test.jsonnet' -not -path "$REPO_DIR/vendor/*" -not -path "$REPO_DIR/**/vendor/*"
  else
    echo "$1"
  fi
}

find_tests "${1:-}" | while read -r line; do
  echo "# ${line}"
  if ! jsonnet -J "$REPO_DIR/libsonnet" -J "$REPO_DIR/vendor" -J "$REPO_DIR/metrics-catalog" -J "$REPO_DIR/services" "$line"; then
    echo "# ${line} failed"
    echo "# Retry with \`jsonnet -J \"$REPO_DIR/libsonnet\" -J \"$REPO_DIR/vendor\" -J \"$REPO_DIR/metrics-catalog\" -J \"$REPO_DIR/services\" \"$line\"\`"
    exit 1
  fi
done
