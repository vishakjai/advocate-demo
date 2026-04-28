#!/bin/bash
# ./astro.sh [dev|build|preview]

set -euo pipefail

cd "$(dirname "$0")" || exit 1

if ! parallel --version | head -1 | grep -E 'GNU parallel' >/dev/null; then
  echo >&2 'You need GNU parallel to run this script, please install it. On Mac OSX you can run "brew install parallel".'
  exit 1
fi

cmd="${1:-build}"

rm -rf src/content/docs src/content/img
mkdir -p src/content
cp -r ../docs src/content/docs
cp -r ../img src/content/img

find src/content/docs -name 'README.md' | parallel mv '{}' '{//}/index.md'
find src/content/docs -name '*.md' | parallel -n 20 ruby astro_process_md.rb

npm run "$cmd"
