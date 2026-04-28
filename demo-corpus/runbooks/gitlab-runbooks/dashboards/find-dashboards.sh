#!/usr/bin/env bash
# vim: ai:ts=2:sw=2:expandtab

set -euo pipefail
# Also fail when subshells fail
shopt -s inherit_errexit || true # Not all bash shells have this

IFS=$'\n\t'
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cd "${SCRIPT_DIR}"

source "grafana-tools.lib.sh"

prepare

find_dashboards "$@"
