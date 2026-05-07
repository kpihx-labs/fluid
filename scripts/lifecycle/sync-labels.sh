#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

target_host="${1:-}"
fluid_state_bootstrap

if [ -n "$target_host" ]; then
  fluid_host_exists "$target_host" || fluid_die "Unknown host '$target_host'."
fi

bash "$ROOT_DIR/scripts/runtime/swarm.sh" sync-labels "$target_host"
