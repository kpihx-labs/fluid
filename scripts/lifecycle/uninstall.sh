#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

target_host="${1:-$(fluid_local_host_name)}"
[ -n "$target_host" ] || fluid_die "Could not match this machine to fabric/hosts.json."
fluid_host_exists "$target_host" || fluid_die "Unknown host '$target_host'."

local_swarm_state() {
  if ! command -v docker >/dev/null 2>&1; then
    printf 'missing\n'
    return 0
  fi
  docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || printf 'inactive\n'
}

remove_legacy_nomad_artifacts() {
  fluid_run_privileged "Disable legacy Fluid Nomad unit" systemctl disable --now fluid-nomad.service 2>/dev/null || true
  fluid_run_privileged "Remove legacy Fluid Nomad unit" rm -f "$FLUID_SYSTEMD_UNIT_DIR/fluid-nomad.service"
  fluid_run_privileged "Remove legacy Nomad config dir" rm -rf /etc/nomad.d
  fluid_run_privileged "Remove legacy Nomad state dir" rm -rf /var/lib/nomad
  fluid_run_privileged "Remove legacy Nomad binary" rm -f /usr/local/bin/nomad
}

remove_fluid_runtime_dirs() {
  fluid_run_privileged "Remove Fluid etc root" rm -rf "$FLUID_ETC_ROOT"
  fluid_run_privileged "Remove Fluid var root" rm -rf "$FLUID_VAR_ROOT"
}

leave_swarm_if_active() {
  if [ "$(local_swarm_state)" = "active" ]; then
    fluid_run_privileged "Leave the Fluid Swarm cluster" docker swarm leave --force
  fi
}

fluid_state_bootstrap

if [ -w "$FLUID_STATE_PATH" ]; then
  fluid_mark_retired "$target_host"
  fluid_remove_authority_host "$target_host"
else
  fluid_warn "State file is not writable locally. Cluster state will not be updated from this host."
fi

bash "$ROOT_DIR/scripts/runtime/continuity.sh" uninstall "$target_host"
leave_swarm_if_active
remove_legacy_nomad_artifacts
remove_fluid_runtime_dirs

fluid_info "Local Fluid uninstall completed for '$target_host'."
