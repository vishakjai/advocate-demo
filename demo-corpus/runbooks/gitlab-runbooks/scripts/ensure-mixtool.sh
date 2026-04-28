#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if command -v mixtool >/dev/null; then
  # Our work here is done...
  exit
fi

cat <<-EOF
mixtool is not installed.

mixtool is currently not available through asdf, please install using:

$ go install github.com/monitoring-mixins/mixtool/cmd/mixtool@main
$ asdf reshim golang # If you're using asdf

For more information on mixins, consult the docs/monitoring/mixins.md readme in this repo.
EOF

exit 1
