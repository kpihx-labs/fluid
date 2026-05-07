#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

host="${1:-}"
[ -n "$host" ] || fluid_die "Usage: ./fluid.sh demote <host>"
fluid_host_exists "$host" || fluid_die "Unknown host '$host'."

fluid_state_bootstrap
fluid_require_writable_state
bash "$ROOT_DIR/scripts/runtime/swarm.sh" demote "$host"
fluid_info "Demoted '$host' to Fluid worker."
