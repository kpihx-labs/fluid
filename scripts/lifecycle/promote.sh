#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

host="${1:-}"
[ -n "$host" ] || fluid_die "Usage: ./fluid.sh promote <host>"
fluid_host_exists "$host" || fluid_die "Unknown host '$host'."
[ "$(fluid_host_swarm_role "$host")" = "manager" ] || fluid_die "Host '$host' is not configured for manager duties."

fluid_state_bootstrap
fluid_require_writable_state
"$ROOT_DIR/scripts/runtime/swarm.sh" promote "$host"
fluid_info "Promoted '$host' to Fluid manager."
