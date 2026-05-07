#!/usr/bin/env bash
# Shared low-level helpers for Fluid.
#
# This file intentionally centralizes shell behavior, logging, privilege
# handling, and local platform detection. Every higher-level script should stay
# declarative and let this file own generic shell mechanics.

set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FLUID_ROOT="$(cd "$LIB_DIR/../.." && pwd)"
source "$FLUID_ROOT/fabric/defaults.env"

fluid_log() {
  local level=$1
  shift
  printf '[%s] %s\n' "$level" "$*"
}

fluid_info() { fluid_log INFO "$@"; }
fluid_warn() { fluid_log WARN "$@"; }
fluid_error() { fluid_log ERROR "$@"; }

fluid_die() {
  fluid_error "$@"
  exit 1
}

fluid_require_cmd() {
  local cmd=$1
  command -v "$cmd" >/dev/null 2>&1 || fluid_die "Required command '$cmd' is missing."
}

fluid_ensure_dir() {
  local dir=$1
  [ -d "$dir" ] || mkdir -p "$dir"
}

fluid_run() {
  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN: $*"
  else
    fluid_info "RUN: $*"
    "$@"
  fi
}

fluid_run_privileged() {
  local reason=$1
  shift

  if [ "${FLUID_DRY_RUN}" = "true" ]; then
    fluid_info "DRY-RUN (privileged: $reason): $*"
    return 0
  fi

  case "${FLUID_PRIVILEGE_TOOL}" in
    sudo)
      fluid_info "RUN (sudo: $reason): $*"
      sudo "$@"
      ;;
    doas)
      fluid_info "RUN (doas: $reason): $*"
      doas "$@"
      ;;
    sui)
      command -v sui >/dev/null 2>&1 || fluid_die "Privilege tool 'sui' is configured but missing."
      fluid_info "RUN (sui: $reason): $*"
      sui -r "$reason" "$@"
      ;;
    *)
      command -v "$FLUID_PRIVILEGE_TOOL" >/dev/null 2>&1 || fluid_die "Privilege tool '$FLUID_PRIVILEGE_TOOL' is missing."
      fluid_info "RUN ($FLUID_PRIVILEGE_TOOL: $reason): $*"
      "$FLUID_PRIVILEGE_TOOL" "$@"
      ;;
  esac
}

fluid_detect_hostname() {
  hostname 2>/dev/null || uname -n
}

fluid_detect_platform() {
  local sys
  sys="$(uname -s)"
  case "$sys" in
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "wsl"
      elif [ -f /etc/os-release ]; then
        . /etc/os-release
        case "${ID:-linux}" in
          debian) echo "debian" ;;
          ubuntu) echo "ubuntu" ;;
          *) echo "linux" ;;
        esac
      else
        echo "linux"
      fi
      ;;
    Darwin) echo "mac" ;;
    Android) echo "android" ;;
    *) echo "unknown" ;;
  esac
}

fluid_yesno() {
  case "${1:-false}" in
    true|True|TRUE|1|yes|YES|on|ON) echo "yes" ;;
    *) echo "no" ;;
  esac
}

fluid_is_linux_family() {
  case "${1:-}" in
    linux|ubuntu|debian|pve) return 0 ;;
    *) return 1 ;;
  esac
}

fluid_package_present() {
  case "${1:-}" in
    jq) command -v jq >/dev/null 2>&1 ;;
    curl) command -v curl >/dev/null 2>&1 ;;
    unzip) command -v unzip >/dev/null 2>&1 ;;
    tailscale) command -v tailscale >/dev/null 2>&1 ;;
    docker|docker.io|docker-ce) command -v docker >/dev/null 2>&1 ;;
    python3-yaml) python3 -c 'import yaml' >/dev/null 2>&1 || /usr/bin/python3 -c 'import yaml' >/dev/null 2>&1 || command -v uv >/dev/null 2>&1 ;;
    rsync) command -v rsync >/dev/null 2>&1 ;;
    systemd) command -v systemctl >/dev/null 2>&1 ;;
    *) command -v "${1:-}" >/dev/null 2>&1 ;;
  esac
}

fluid_require_service_running() {
  local service=$1
  command -v systemctl >/dev/null 2>&1 || fluid_die "systemctl is required to verify service '$service'."
  systemctl is-active --quiet "$service" || fluid_die "Service '$service' is not active."
}
