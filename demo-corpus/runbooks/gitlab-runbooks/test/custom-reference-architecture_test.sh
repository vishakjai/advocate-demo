#!/usr/bin/env bash

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# See reference-architectures/README.md for details of how this works
testDisablePraefectForGetHybrid() {
  output_dir=$(mktemp -d)
  overrides_dir=$(mktemp -d)

  echo '{ praefect+: { enable: false } }' >"$overrides_dir/gitlab-metrics-options.libsonnet"

  "$REPO_DIR/scripts/generate-reference-architecture-config.sh" "$REPO_DIR/reference-architectures/get-hybrid/src" "$output_dir" "$overrides_dir"

  assertTrue "Gitaly dashboard generated" "[ -f $output_dir/dashboards/gitaly.json ]"
  assertFalse "Praefect dashboard generated" "[ -f $output_dir/dashboards/praefect.json ]"
}

# Load shUnit2.
# shellcheck source=lib/shunit2
. "$REPO_DIR/test/lib/shunit2"
