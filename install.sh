#!/usr/bin/env bash
# Compatibility wrapper kept on purpose.
# Older muscle memory may still call ./install.sh. We redirect to the guided
# bootstrap action so the operator lands on the new lifecycle path immediately.

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT_DIR/fluid.sh" bootstrap "$@"
