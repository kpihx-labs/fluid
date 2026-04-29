#!/bin/bash
# -----------------------------------------------------------------------------
# 🧹 BOOTSTRAP > 02_TABULA_RASA > LINUX (linux.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Restores a Linux host to a pristine pre-K3s state (Radical Reset).
# WHY: In a distributed system, residual configuration (zombie interfaces, 
# file locks, stale iptables) is the enemy of deterministic deployment.
# This script nukes every K3s, Postgres, and VXLAN artifact to ensure 
# that the next deployment phase starts from a Zero-Drift baseline.
# -----------------------------------------------------------------------------

set -e # WHY: Exit on error to ensure we don't proceed with partial cleanup.

# 1. Path Resolution & Configuration Loading
# -----------------------------------------------------------------------------
# WHY: Access to config.env allows us to know exactly which interfaces 
# and directories were used by previous versions of the deployment.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# WHY: config.env is our Single Source of Truth (SSOT).
source "$SCRIPT_DIR/../../../config.env"

# 🏛️ Privileged Access Logic
# -----------------------------------------------------------------------------
# WHY: Using the standard 'sudo' command defined in config.env to ensure
# the script remains agnostic and portable.
run_privileged() {
    # WHY: $SUDO_CMD is 'sudo' by default. No personal gateway used.
    $SUDO_CMD "$@"
}

echo "--- 🧹 STARTING HYPER-DOCUMENTED RADICAL CLEANUP (TABULA RASA) ---"

# 2. Stop & Uninstall K3s Engine
# -----------------------------------------------------------------------------
# WHY: The engine must be stopped to release network locks and mount points.
# We call both server and agent uninstallers to cover all potential roles.
echo "[Step 1] Neutralizing K3s engine..."
if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    echo "[INFO] Found Server Uninstaller. Running..."
    run_privileged /usr/local/bin/k3s-uninstall.sh || true
fi
if [ -f /usr/local/bin/k3s-agent-uninstall.sh ]; then
    echo "[INFO] Found Agent Uninstaller. Running..."
    run_privileged /usr/local/bin/k3s-agent-uninstall.sh || true
fi

# 3. State Layer Neutralization (Database)
# -----------------------------------------------------------------------------
# WHY: PostgreSQL or CockroachDB processes hold locks on data directories. 
# We use SIGKILL (-9) to ensure they are terminated immediately.
echo "[Step 2] Terminating Database processes and containers..."
run_privileged pkill -9 cockroach || true
run_privileged pkill -9 postgres || true
# WHY: If Postgres was running in Docker (Ubuntu), we must remove the container
# to avoid port conflicts and data corruption on the next run.
if command -v docker &> /dev/null; then
    echo "[INFO] Removing fluid-db container if exists..."
    docker rm -f fluid-db &> /dev/null || true
fi

# 4. Overlay Network Deconstruction
# -----------------------------------------------------------------------------
# WHY: Virtual interfaces like VXLAN and Bridges persist in the kernel.
# We use variables from config.env to target the correct logical names.
echo "[Step 3] Dismantling virtual network interfaces ($CLUSTER_INTERFACE)..."
run_privileged ip link set "$CLUSTER_INTERFACE" down || true
run_privileged ip link delete "$CLUSTER_INTERFACE" 2>/dev/null || true
run_privileged ip link delete "$FLUID_BRIDGE" 2>/dev/null || true

# 5. Filesystem Purge (Data & Config)
# -----------------------------------------------------------------------------
# WHY: Wiping /var/lib/rancher and /etc/rancher removes the cluster "memory".
# This prevents new installations from trying to join a non-existent cluster.
echo "[Step 4] Purging residual data directories..."
run_privileged rm -rf /var/lib/rancher/k3s /etc/rancher/k3s || true
run_privileged rm -rf /var/lib/longhorn || true
# WHY: Cleanup of database data and legacy logs from previous runs.
run_privileged rm -rf "$HOME/cockroach-data" "$HOME/cockroach.log" || true

echo "--- ✅ TABULA RASA COMPLETE: SYSTEM IS READY FOR RECONSTRUCTION ---"
