#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"

fluid_info "Android participation path"
fluid_info "v1 keeps Android lightweight: observer/helper/limited continuity only."
fluid_info "No authority-grade support is assumed in this first operational cut."
