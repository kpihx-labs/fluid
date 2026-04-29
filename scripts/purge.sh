#!/bin/bash
# -----------------------------------------------------------------------------
# 💀 MASTER PURGE ORCHESTRATOR (purge.sh) - 100% AGNOSTIC
# -----------------------------------------------------------------------------
# PURPOSE: Automatically detects the host OS and triggers a 100% radical purge.
# WHY: Follows the $NODE_OS.sh convention in the 99_purge directory.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"

# 1. Sovereign Confirmation Prompt
# -----------------------------------------------------------------------------
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "⚠️  NUCLEAR PURGE ON $NODE_NAME ($NODE_OS) ⚠️"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
read -p "Confirm radical wipe? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "[ABORT] Cancelled."
    exit 0
fi

# 2. Execution (Convention-Based)
# -----------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/99_purge/${NODE_OS}.sh" ]; then
    bash "$SCRIPT_DIR/99_purge/${NODE_OS}.sh"
else
    echo "[ERROR] No purge implementation found for $NODE_OS."
    exit 1
fi

echo "--- ✅ PURGE COMPLETE FOR $NODE_NAME ---"
