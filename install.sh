#!/usr/bin/env bash
# Compatibility wrapper kept on purpose.
# Older muscle memory may still call ./install.sh.
# It now chooses bootstrap or join based on the current local/state situation.

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"
source "$ROOT_DIR/scripts/lib/inventory.sh"

target_host="${1:-$(fluid_local_host_name)}"
fluid_state_bootstrap

if [ -n "$(fluid_manager_host)" ]; then
  exec "$ROOT_DIR/fluid.sh" join "${target_host:+$target_host}"
else
  exec "$ROOT_DIR/fluid.sh" bootstrap "${target_host:+$target_host}"
fi
