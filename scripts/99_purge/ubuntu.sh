#!/bin/bash
# -----------------------------------------------------------------------------
# 💀 PURGE > UBUNTU (ubuntu.sh)
# -----------------------------------------------------------------------------
# PURPOSE: 100% total destruction of KpihX-Labs artifacts on Ubuntu.
# WHY: This is the "Nuclear Option" used when a node needs to be fully 
# repurposed or reset without leaving any cluster-related residues.
# -----------------------------------------------------------------------------

set -e

# 1. Configuration Loading
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

# 🏛️ Privileged Access Logic
# -----------------------------------------------------------------------------
run_privileged() {
    # WHY: Using the standard sudo command for portability.
    $SUDO_CMD "$@"
}

echo "--- 💀 INITIATING HYPER-DOCUMENTED RADICAL PURGE (UBUNTU) ---"

# 2. Engine Destruction
# -----------------------------------------------------------------------------
echo "[Step 1] Destroying K3s Engine binaries and services..."
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    run_privileged /usr/local/bin/k3s-uninstall.sh || true
fi
if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
    run_privileged /usr/local/bin/k3s-agent-uninstall.sh || true
fi

# 3. State Store Destruction (Docker)
# -----------------------------------------------------------------------------
# WHY: On Ubuntu, Postgres runs in a container. We remove both the 
# container and any local data mounts.
echo "[Step 2] Purging Containerized State (fluid-db)..."
if command -v docker &> /dev/null; then
    docker rm -f fluid-db 2>/dev/null || true
    # WHY: Optional: We keep the image 'postgres:alpine' for faster re-install 
    # unless a full wipe is explicitly requested.
fi

# 4. Networking Deconstruction
# -----------------------------------------------------------------------------
echo "[Step 3] Deleting VXLAN and Bridge artifacts ($CLUSTER_INTERFACE)..."
run_privileged ip link delete "$CLUSTER_INTERFACE" 2>/dev/null || true
run_privileged ip link delete "$FLUID_BRIDGE" 2>/dev/null || true

# 5. Configuration Purge
# -----------------------------------------------------------------------------
echo "[Step 4] Finalizing filesystem cleanup..."
run_privileged rm -rf /etc/rancher /var/lib/rancher /var/lib/longhorn || true
run_privileged rm -rf "$HOME/k3s" "$HOME/.kube" || true
run_privileged rm -rf "$HOME/cockroach-data" "$HOME/cockroach.log" || true

echo "--- 💀 UBUNTU PURGE COMPLETE ---"
