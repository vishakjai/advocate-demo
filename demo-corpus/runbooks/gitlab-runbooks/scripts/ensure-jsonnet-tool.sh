#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

if command -v jsonnet-tool >/dev/null; then
  # Our work here is done...
  exit
fi

cat <<-EOF
jsonnet-tool is not installed.

The easiest way to install jsonnet-tool is through asdf, by running the following command:

\` asdf plugin add jsonnet-tool https://gitlab.com/gitlab-com/gl-infra/asdf-gl-infra.git; asdf install\`

For more information, consult the README.md
EOF

exit 1
