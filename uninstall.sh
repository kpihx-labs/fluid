#!/usr/bin/env bash
# Compatibility wrapper kept on purpose.
# The new lifecycle model does not use a generic "purge everything" command as
# the primary operator entrypoint. Retirement is intentional and host-specific.

set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$ROOT_DIR/fluid.sh" retire "$@"
