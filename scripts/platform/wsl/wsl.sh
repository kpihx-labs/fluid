#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"

fluid_info "WSL participation path"
fluid_info "v1 treats WSL as execution-oriented unless host policy is expanded later."
