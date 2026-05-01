#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

target_host="${1:-$(fluid_local_host_name)}"
package_hint_env=""
package_hint_value=""
missing_packages=()

if [ -n "$target_host" ] && fluid_host_exists "$target_host"; then
  package_hint_env="$(fluid_host_field "$target_host" '.runtime.package_hint_env // empty')"
fi

if [ -n "$package_hint_env" ] && [ -n "${!package_hint_env:-}" ]; then
  package_hint_value="${!package_hint_env}"
else
  package_hint_value="${FLUID_LINUX_PACKAGES:-}"
fi

fluid_info "Linux host preparation"
fluid_info "- underlay: $(fluid_underlay_type)"
fluid_info "- interface: $(fluid_underlay_interface)"
fluid_info "- package baseline: ${package_hint_value:-none}"

for package_name in $package_hint_value; do
  if ! fluid_package_present "$package_name"; then
    missing_packages+=("$package_name")
  fi
done

if [ "${#missing_packages[@]}" -gt 0 ]; then
  fluid_info "Installing missing packages: ${missing_packages[*]}"
  fluid_install_packages "Install Fluid Linux prerequisites" "${missing_packages[@]}"
fi

if [ "$(fluid_require_underlay)" = "true" ] && [ "$(fluid_underlay_type)" = "tailscale" ]; then
  fluid_require_cmd tailscale
fi

fluid_require_cmd jq
fluid_require_cmd curl
fluid_require_cmd unzip
fluid_require_cmd docker
fluid_require_cmd python3
if ! fluid_package_present python3-yaml; then
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_warn "python3-yaml is still unavailable after simulated install. Real apply will install it."
  else
    fluid_die "python3-yaml is still unavailable after package install."
  fi
fi

fluid_run_privileged "Enable Docker engine for Fluid" systemctl enable --now docker
if ! groups "$USER" | grep -q '\bdocker\b'; then
  fluid_run_privileged "Add user to docker group" usermod -aG docker "$USER"
  fluid_warn "User $USER added to docker group. You may need to log out and log back in for permissions to apply locally."
fi
