#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"
source "$ROOT_DIR/scripts/lib/tailscale.sh"

fluid_state_bootstrap

local_host="$(fluid_local_host_name)"
local_platform="$(fluid_detect_platform)"

fluid_info "Fluid root: $FLUID_ROOT"
fluid_info "Hosts: $FLUID_HOSTS_PATH"
fluid_info "State: $FLUID_STATE_PATH"
fluid_info "Runtime dir: $FLUID_RUNTIME_DIR"
fluid_info "Tailscale status: $(fluid_tailscale_status)"
fluid_info "Local platform detection: $local_platform"
fluid_info "Local host entry: ${local_host:-unmatched}"
fluid_info "Underlay: $(fluid_underlay_type) via $(fluid_underlay_interface)"
fluid_info "Advertise mode: $(fluid_advertise_mode)"
fluid_info "Manager host: $(fluid_manager_host || true)"
fluid_info "Manager advertise addr: $(fluid_manager_advertise_addr || true)"

printf '\nAuthority hosts:\n'
if fluid_authority_set | grep -q .; then
  fluid_authority_set | sed 's/^/  - /'
else
  echo "  - none"
fi

printf '\nPortable truth replicas:\n'
if fluid_portable_truth_replicas | grep -q .; then
  fluid_portable_truth_replicas | sed 's/^/  - /'
else
  echo "  - none"
fi

printf '\nHost summary:\n'
while read -r host; do
  [ -n "$host" ] || continue
  printf -- "- %s: platform=%s role=%s survivor=%s authority=%s continuity=%s\n" \
    "$host" \
    "$(fluid_host_field "$host" '.platform')" \
    "$(fluid_host_swarm_role "$host")" \
    "$(fluid_effective_host_bool "$host" "SURVIVOR_CAPABLE" '.survivor_capable' "false")" \
    "$(fluid_effective_host_bool "$host" "AUTHORITY_ELIGIBLE" '.authority_eligible' "false")" \
    "$(fluid_effective_host_bool "$host" "CONTINUITY_ENABLED" '.resources.continuity.enabled // .capabilities.continuity_host' "$CONTINUITY_ENABLED_DEFAULT")"
done < <(fluid_inventory_hosts)

printf '\nLocal swarm status:\n'
"$ROOT_DIR/scripts/runtime/swarm.sh" status "${local_host:-}"
