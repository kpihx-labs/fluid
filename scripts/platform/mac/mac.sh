#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"

fluid_info "macOS participation path"
fluid_info "v1 supports execution and selected continuity behavior."
fluid_info "Manager duties are intentionally disabled by default. Use macOS as a Swarm worker unless you opt in explicitly."
