#!/bin/bash
# -----------------------------------------------------------------------------
# 🛡️ NETWORK > 01_VIP_SEED > LINUX (linux.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Assigns the Virtual IP (VIP) to the VXLAN interface on Linux.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../config.env"

run_privileged() { $SUDO_CMD "$@"; }

echo "--- 🛡️ INITIALIZING HA LAYER (LINUX SEED) ---"

echo "[Step 1] Binding VIP $CLUSTER_VIP to interface $CLUSTER_INTERFACE..."
run_privileged ip addr add "$CLUSTER_VIP/24" dev "$CLUSTER_INTERFACE" 2>/dev/null || true

if command -v arping &> /dev/null; then
    echo "[Step 2] Broadcasting Gratuitous ARP for VIP..."
    run_privileged arping -c 3 -I "$CLUSTER_INTERFACE" -S "$CLUSTER_VIP" "$CLUSTER_VIP" || true
fi

echo "--- ✅ HA SEED IS ACTIVE ---"
