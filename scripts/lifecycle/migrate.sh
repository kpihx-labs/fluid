#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT_DIR/scripts/lib/common.sh"

from_host="${1:-}"
to_host="${2:-}"
[ -n "$from_host" ] && [ -n "$to_host" ] || fluid_die "Usage: ./fluid.sh migrate <from-host> <to-host>"

"$ROOT_DIR/scripts/lifecycle/promote.sh" "$to_host"
"$ROOT_DIR/scripts/lifecycle/demote.sh" "$from_host"

fluid_info "Migration complete: authority moved from $from_host to $to_host."
