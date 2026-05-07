#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

fluid_state_bootstrap
fluid_info "Rebuilding the authority set from the live Swarm manager list."
bash "$ROOT_DIR/scripts/runtime/swarm.sh" sync-labels

if fluid_authority_set | grep -q .; then
  fluid_info "Authority rebuilt as: $(fluid_authority_set | paste -sd ',' -)"
else
  fluid_die "No authority host could be derived from the current cluster."
fi
