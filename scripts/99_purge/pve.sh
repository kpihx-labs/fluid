#!/bin/bash
# -----------------------------------------------------------------------------
# 💀 PURGE > PVE (pve.sh)
# -----------------------------------------------------------------------------
# PURPOSE: 100% total destruction of KpihX-Labs artifacts on the PVE host.
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

echo "--- 💀 INITIATING HYPER-DOCUMENTED RADICAL PURGE (PVE) ---"

# 2. Engine Destruction
# -----------------------------------------------------------------------------
# WHY: Removing the binary and all its associated systemd services.
echo "[Step 1] Destroying K3s Control Plane binaries and services..."
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    run_privileged /usr/local/bin/k3s-uninstall.sh || true
fi

# 3. State Store Destruction (Native PostgreSQL)
# -----------------------------------------------------------------------------
# WHY: PVE uses native Postgres. We purge the package and all its data.
echo "[Step 2] Purging Native PostgreSQL and its associated data..."
run_privileged systemctl stop postgresql || true
# WHY: 'purge' removes both the binaries AND the global config files.
run_privileged apt-get purge -y postgresql* || true
run_privileged rm -rf /etc/postgresql /var/lib/postgresql /var/log/postgresql || true

# 4. Networking Deconstruction
# -----------------------------------------------------------------------------
# WHY: Removing the logical overlay interfaces to free up kernel resources.
echo "[Step 3] Deleting VXLAN and Bridge artifacts ($CLUSTER_INTERFACE)..."
run_privileged ip link delete "$CLUSTER_INTERFACE" 2>/dev/null || true
run_privileged ip link delete "$FLUID_BRIDGE" 2>/dev/null || true

# 5. Configuration Purge
# -----------------------------------------------------------------------------
# WHY: Wiping any remaining cluster-wide or local-node settings.
echo "[Step 4] Finalizing filesystem cleanup..."
run_privileged rm -rf /etc/rancher /var/lib/rancher /var/lib/longhorn || true
run_privileged rm -rf "$HOME/k3s" "$HOME/.kube" || true

echo "--- ✅ PVE PURGE COMPLETE: HOST IS NATIVE AND CLEAN ---"
