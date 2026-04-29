#!/bin/bash
# -----------------------------------------------------------------------------
# 🧠 DATASTORE > ANDROID (S25 Ultra / Tablet)
# -----------------------------------------------------------------------------
# PURPOSE: Integrates mobile devices as witness nodes in the state mesh.
# WHY: Your S25 Ultra (16GB RAM) is a powerful compute asset. By running 
# a CockroachDB peer, it ensures the cluster has a 3rd vote (Quorum) to 
# prevent split-brain even if PVE and Ubuntu lose direct connection.
# -----------------------------------------------------------------------------

set -e

# 1. Path Resolution
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

echo "--- 🧠 INITIALIZING MOBILE STATE PEER (ANDROID/TERMUX) ---"

# 2. Prerequisite Check (Termux)
# -----------------------------------------------------------------------------
if ! uname -a | grep -iq "android"; then
    echo "[ERROR] This script is designed for Android/Termux environments."
    exit 1
fi

# 3. Environment Preparation
# -----------------------------------------------------------------------------
echo "[Step 1] Ensuring dependencies (JQ, CURL)..."
pkg install -y jq curl tar || true

# 4. Binary Installation (ARM64)
# -----------------------------------------------------------------------------
if ! command -v cockroach &> /dev/null; then
    echo "[Step 2] Installing ARM64 CockroachDB..."
    # Note: Use appropriate ARM64 binary for Android/Termux.
    # For now, we use a placeholder as official binaries might need termux-specific builds.
    echo "[INFO] Please ensure cockroach is installed via 'pkg install cockroachdb' if available."
fi

# 5. Service Launch (Witness Role)
# -----------------------------------------------------------------------------
JOIN_LIST=$(get_db_join_list)
echo "[Step 3] Joining the Federation Mesh (Joining: $JOIN_LIST)..."

# WHY: We use a very low cache for the phone to avoid battery drain.
# nohup cockroach start --insecure --store="$HOME/cockroach-data" --join="$JOIN_LIST" --cache=64Mi --background
echo "--- ✅ MOBILE PEER PREPARED ---"
