#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"
source "$ROOT_DIR/scripts/lib/tailscale.sh"

status_format="${1:-text}"
fluid_state_bootstrap

local_host="$(fluid_local_host_name)"
local_platform="$(fluid_detect_platform)"

if [ "$status_format" = "--json" ] || [ "$status_format" = "json" ]; then
  jq -n \
    --arg fluid_root "$FLUID_ROOT" \
    --arg hosts_path "$FLUID_HOSTS_PATH" \
    --arg state_path "$FLUID_STATE_PATH" \
    --arg render_dir "$FLUID_RENDER_DIR" \
    --arg tailscale_status "$(fluid_tailscale_status)" \
    --arg local_platform "$local_platform" \
    --arg local_host "${local_host:-}" \
    --arg underlay "$(fluid_underlay_type)" \
    --arg underlay_interface "$(fluid_underlay_interface)" \
    --arg advertise_mode "$(fluid_advertise_mode)" \
    --arg manager_host "$(fluid_manager_host || true)" \
    --arg manager_advertise_addr "$(fluid_manager_advertise_addr || true)" \
    --argjson identity "$(fluid_local_identity_sources_json)" \
    --argjson authority_hosts "$(jq -Rc 'select(length > 0)' < <(fluid_authority_set || true) | jq -s '.')" \
    --argjson portable_truth_replicas "$(jq -Rc 'select(length > 0)' < <(fluid_portable_truth_replicas || true) | jq -s '.')" \
    --argjson hosts "$(
      while read -r host; do
        [ -n "$host" ] || continue
        jq -cn \
          --arg host "$host" \
          --arg platform "$(fluid_host_field "$host" '.platform')" \
          --arg role "$(fluid_host_role "$host")" \
          --arg survivor "$(fluid_host_survivor_capable "$host")" \
          --arg authority_eligible "$(fluid_host_authority_eligible "$host")" \
          --arg continuity "$(fluid_host_continuity_enabled "$host")" \
          '{
            name: $host,
            platform: $platform,
            role: $role,
            survivor_capable: ($survivor == "true"),
            authority_eligible: ($authority_eligible == "true"),
            continuity_enabled: ($continuity == "true")
          }'
      done < <(fluid_inventory_hosts) | jq -s '.'
    )" \
    --arg local_swarm_state "$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || printf 'inactive')" \
    --arg local_control_plane "$([ "$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null || printf 'false')" = "true" ] && printf 'manager' || printf 'worker-or-none')" \
    '{
      fluid_root: $fluid_root,
      hosts_path: $hosts_path,
      state_path: $state_path,
      render_dir: $render_dir,
      tailscale_status: $tailscale_status,
      local_platform: $local_platform,
      local_host: (if $local_host == "" then null else $local_host end),
      local_identity: $identity,
      underlay: {
        type: $underlay,
        interface: $underlay_interface
      },
      advertise_mode: $advertise_mode,
      manager_host: (if $manager_host == "" then null else $manager_host end),
      manager_advertise_addr: (if $manager_advertise_addr == "" then null else $manager_advertise_addr end),
      authority_hosts: $authority_hosts,
      portable_truth_replicas: $portable_truth_replicas,
      hosts: $hosts,
      local_swarm_status: {
        state: $local_swarm_state,
        control_plane: $local_control_plane
      }
    }'
  exit 0
fi

fluid_info "Fluid root: $FLUID_ROOT"
fluid_info "Hosts: $FLUID_HOSTS_PATH"
fluid_info "State: $FLUID_STATE_PATH"
fluid_info "Render dir: $FLUID_RENDER_DIR"
fluid_info "Tailscale status: $(fluid_tailscale_status)"
fluid_info "Local platform detection: $local_platform"
fluid_info "Local host entry: ${local_host:-unmatched}"
fluid_info "Local tailscale IP: $(fluid_local_tailscale_ip || true)"
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
    "$(fluid_host_role "$host")" \
    "$(fluid_host_survivor_capable "$host")" \
    "$(fluid_host_authority_eligible "$host")" \
    "$(fluid_host_continuity_enabled "$host")"
done < <(fluid_inventory_hosts)

printf '\nLocal swarm status:\n'
bash "$ROOT_DIR/scripts/runtime/swarm.sh" status "${local_host:-}"
