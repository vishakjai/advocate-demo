#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

REPO_DIR=$(
  cd "$(dirname "${BASH_SOURCE[0]}")/.."
  pwd
)

tmpdir=$(mktemp -d)
trap 'rm -rf "${tmpdir}"' EXIT

function replace_marker_section() {
  local section_name=$1
  local snippet_source=$2
  local file=$3
  local tmpoutput
  tmpoutput=$(mktemp)

  awk -v snippet_source="$snippet_source" '
    /^<!-- MARKER:'"$section_name"': do not edit this section directly. -->$/ {
      in_marker = 1;
      print;
      while ((getline line < snippet_source) > 0)
        print line
      close(snippet_source)
    }

    /^<!-- END_MARKER:'"$section_name"' -->$/ {
      in_marker = 0;
    }

    // {
      if (in_marker != 1) { print }
    }' "$file" >"$tmpoutput"

  mv "$tmpoutput" "$file"
}

function render_readme_for_dir() {
  local dir=$1

  jsonnet-tool \
    -J "libsonnet" \
    -J "reference-architectures/default-overrides" \
    -J "$dir/src" \
    -J "vendor" \
    render \
    "$dir/src/docs.jsonnet" \
    -m "${tmpdir}"

  replace_marker_section "slis" "$tmpdir/README.snippet-slis.md" "$dir/README.md"
  replace_marker_section "saturation" "$tmpdir/README.snippet-saturation.md" "$dir/README.md"

  echo "$dir/README.md"
}

for i in "${REPO_DIR}"/reference-architectures/*/src/docs.jsonnet; do
  dir=$(
    cd "$(dirname "$i")/.."
    pwd
  )

  render_readme_for_dir "$dir"
done
