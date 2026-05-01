#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

fluid_require_cmd jq
fluid_state_bootstrap

fluid_info "Auditing host inventory."
jq -e '.hosts and (.hosts | type == "array") and (.hosts | length > 0)' "$FLUID_HOSTS_PATH" >/dev/null || fluid_die "config/hosts.json must define a non-empty hosts array."

while read -r host; do
  [ -n "$host" ] || continue
  fluid_host_field "$host" '.platform' >/dev/null
  fluid_host_field "$host" '.profile' >/dev/null
  fluid_host_field "$host" '.network.tailscale_name' >/dev/null
  fluid_host_swarm_role "$host" >/dev/null
done < <(fluid_inventory_hosts)

fluid_info "Auditing authority policy."
fluid_policy_authority_size >/dev/null
fluid_policy_min_authority_size >/dev/null
fluid_require_authority_eligible >/dev/null
fluid_require_swarm_manager >/dev/null

fluid_info "Auditing mutable state."
if fluid_authority_set | grep -q .; then
  while read -r host; do
    [ -n "$host" ] || continue
    fluid_host_exists "$host" || fluid_die "Authority host '$host' does not exist in config/hosts.json."
  done < <(fluid_authority_set)
fi

manager_host="$(fluid_manager_host || true)"
if [ -n "$manager_host" ]; then
  fluid_host_exists "$manager_host" || fluid_die "Manager host '$manager_host' does not exist in config/hosts.json."
fi

fluid_info "Auditing directories."
fluid_ensure_dir "$FLUID_CONFIG_DIR"
fluid_ensure_dir "$FLUID_PROFILES_DIR"
fluid_ensure_dir "$FLUID_POLICIES_DIR"
fluid_ensure_dir "$FLUID_STATE_DIR"
fluid_ensure_dir "$FLUID_RENDERED_DIR"
fluid_ensure_dir "$FLUID_BACKUP_DIR"
fluid_ensure_dir "$FLUID_CACHE_DIR"
fluid_ensure_dir "$FLUID_LOG_DIR"
fluid_ensure_dir "$FLUID_PROJECT_RENDER_DIR"

fluid_info "Auditing cluster prerequisites."
fluid_require_cmd python3
fluid_require_cmd rsync

fluid_info "Audit passed."
