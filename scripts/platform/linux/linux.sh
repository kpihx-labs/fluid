#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"
source "$ROOT_DIR/scripts/lib/tailscale.sh"

target_host="${1:-$(fluid_local_host_name)}"
[ -n "$target_host" ] || fluid_die "Could not resolve the local host in fabric/hosts.json."

fluid_info "Linux host prerequisite audit"
fluid_info "- host: $target_host"
fluid_info "- tailscale identity: $(fluid_host_tailscale_name "$target_host")"
fluid_info "- role: $(fluid_host_role "$target_host")"

fluid_require_cmd tailscale
fluid_require_cmd docker
fluid_require_cmd jq
fluid_require_cmd curl
fluid_require_cmd unzip
fluid_require_cmd python3
fluid_require_cmd rsync

fluid_package_present python3-yaml || fluid_die "PyYAML is missing. Install python3-yaml before running Fluid."
[ "$(fluid_tailscale_status)" = "connected" ] || fluid_die "Tailscale is not connected on this host."
fluid_require_service_running docker

if ! groups "$USER" | grep -q '\bdocker\b'; then
  fluid_die "User '$USER' is not in the docker group."
fi
