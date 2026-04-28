#!/usr/bin/env bash

if ! command -v mixtool >/dev/null; then
  cat <<-EOF
mixtool is not installed.

mixtool is currently not available through asdf, please install using:

\`go install github.com/monitoring-mixins/mixtool/cmd/mixtool@main\`

For more information on mixins, consult the docs/monitoring/mixins.md readme in this repo.
EOF
fi

find mimir-rules -name "mixin.libsonnet" ! -path "*/vendor/*" | while IFS= read -r file; do
  (
    cd "$(dirname "${file}")" || exit
    if test -f ./jsonnetfile.lock.json; then
      jb update
    else
      jb install
    fi

    mixtool generate all --output-alerts "alerts.yaml" --output-rules "rules.yaml" --directory "dashboards" mixin.libsonnet
  )
done
