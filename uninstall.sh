#!/usr/bin/env bash
# Compatibility wrapper kept on purpose.
# Muscle memory may still call ./uninstall.sh.
# It now maps to a real local Fluid uninstall instead of a cluster retirement.

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT_DIR/fluid.sh" uninstall "$@"
