#!/bin/bash
# -----------------------------------------------------------------------------
# 🔧 BOOTSTRAP > 01_PREPARE_OS > LINUX (linux.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Installs all host-level dependencies required for K3s and Longhorn.
# WHY: A K3s node is not just a binary; it requires a set of kernel modules
# and system utilities (iSCSI, NFS, JQ) to operate correctly in a HA cluster.
# This script ensures that both PVE (Debian) and Ubuntu nodes have the 
# same toolset to prevent "missing binary" errors during runtime.
# -----------------------------------------------------------------------------

set -e # WHY: Exit immediately if any command fails to prevent half-baked setups.

# 1. Path Resolution & Configuration Loading
# -----------------------------------------------------------------------------
# WHY: We need SCRIPT_DIR to find config.env relative to this file's location.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# WHY: config.env is our Single Source of Truth (SSOT).
source "$SCRIPT_DIR/../../../config.env"

# 🏛️ Privileged Access Logic
# -----------------------------------------------------------------------------
# WHY: Using the standard 'sudo' command defined in config.env to ensure
# the script remains agnostic and portable across standard Linux environments.
run_privileged() {
    # WHY: $SUDO_CMD is 'sudo' by default. No personal gateway used.
    $SUDO_CMD "$@"
}

echo "--- 🔧 STARTING HYPER-DOCUMENTED OS PREPARATION (LINUX) ---"

# 2. Package Registry Update
# -----------------------------------------------------------------------------
# WHY: Ensuring the apt cache is fresh prevents 'Package not found' errors
# when trying to install the required dependencies.
echo "[Step 1] Refreshing package repositories..."
run_privileged apt-get update -qq

# 3. Core Dependencies Installation
# -----------------------------------------------------------------------------
# WHY: curl/wget (Installation), open-iscsi (Longhorn), nfs-common (NFS mounts),
# jq (JSON parsing), net-tools (Network debugging), arping (VIP management).
echo "[Step 2] Installing system-critical dependencies..."
run_privileged apt-get install -y \
    curl \
    wget \
    open-iscsi \
    nfs-common \
    jq \
    net-tools \
    arping

# 4. Storage Engine Activation (iSCSI)
# -----------------------------------------------------------------------------
# WHY: Longhorn uses iSCSI for block storage delivery. The 'iscsid' service 
# must be enabled and running on every node that participates in storage.
echo "[Step 3] Enabling and Starting iSCSI daemon for Longhorn..."
# WHY: 'enable --now' handles both boot-persistence and immediate startup.
run_privileged systemctl enable --now iscsid || true

echo "--- ✅ LINUX OS PREPARATION COMPLETE: READY FOR ENGINE ---"
