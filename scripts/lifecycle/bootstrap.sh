#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

target_host="${1:-$(fluid_local_host_name)}"
[ -n "$target_host" ] || fluid_die "Could not match this machine to fabric/hosts.json."
fluid_host_exists "$target_host" || fluid_die "Unknown host '$target_host'."

platform="$(fluid_host_field "$target_host" '.platform')"
platform_script="$ROOT_DIR/scripts/platform/$platform/$platform.sh"
[ -f "$platform_script" ] || fluid_die "No platform script exists for '$platform'."

fluid_state_bootstrap
fluid_require_writable_state
fluid_info "Bootstrapping Fluid on '$target_host'."
"$platform_script"
bash "$ROOT_DIR/scripts/runtime/swarm.sh" bootstrap "$target_host"

if [ "$(fluid_host_continuity_enabled "$target_host")" = "true" ]; then
  bash "$ROOT_DIR/scripts/runtime/continuity.sh" render "$target_host"
  if [ "$(fluid_host_field "$target_host" '.runtime.supports_continuity_apply // false')" = "true" ]; then
    bash "$ROOT_DIR/scripts/runtime/continuity.sh" apply "$target_host"
  fi
fi

fluid_info "Bootstrap completed for '$target_host'."
