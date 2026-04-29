#!/bin/bash
# -----------------------------------------------------------------------------
# 🚀 MASTER INSTALLER (install.sh) - 100% AGNOSTIC & CONVENTION-BASED
# -----------------------------------------------------------------------------
# PURPOSE: Automatically sequences the construction of the entire federation.
# WHY: By following a strict naming convention ($NODE_OS.sh),
# we remove complex conditional logic and allow instant scaling to new OS types.
# NOTE: Windows hosts are now unified via the 'wsl' OS type using WSL2.
# -----------------------------------------------------------------------------

set -e

# 1. Path Resolution & Environment Guard
# -----------------------------------------------------------------------------
# WHY: We ensure the script can find its dependencies regardless of where it's called from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_NODE=$1

if [ -z "$TARGET_NODE" ]; then
    echo "[ERROR] Usage: ./install.sh <NODE_NAME> (must match hosts.json)"
    exit 1
fi

# WHY: config.env detects the current node based on hostname/inventory.
source "$SCRIPT_DIR/../config.env"

# 2. Triple Identity Validation (Zero-Trust)
# -----------------------------------------------------------------------------
# Check 1: Existence & Match in JSON
if [ "$NODE_NAME" != "$TARGET_NODE" ]; then
    echo "[ERROR] Identity Mismatch! You are trying to install '$TARGET_NODE' but this host is detected as '$NODE_NAME'."
    exit 1
fi

# Check 2: IP Match (on tailscale0 interface)
REAL_TS_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "UNKNOWN")
if [ "$REAL_TS_IP" != "$NODE_IP" ]; then
    echo "[ERROR] IP Guard! hosts.json expects $NODE_IP but local tailscale0 is $REAL_TS_IP."
    exit 1
fi

# 3. Secure Token Acquisition
# -----------------------------------------------------------------------------
if [ -z "$K3S_TOKEN" ]; then
    read -rs -p "🛡️  Enter K3S Federation Token: " K3S_TOKEN
    echo ""
    export K3S_TOKEN
fi

# 4. Sovereign Confirmation Prompt
# -----------------------------------------------------------------------------
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "⚠️  FLUID-K3S SOVEREIGN INSTALLATION : $NODE_NAME ⚠️"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "Host: $(hostname) | OS: $NODE_OS | Role: $NODE_ROLE | IP: $NODE_IP"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
read -p "Proceed with federation entry? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "[ABORT] Cancelled."
    exit 0
fi

# 3. Execution Engine (Convention-Based)
# -----------------------------------------------------------------------------
run_phase() {
    local phase_path=$1
    local phase_name=$(basename "$phase_path")
    
    echo "--- Phase: $phase_name ---"
    
    # WHY: We follow the $NODE_OS.sh convention for total agnosticism.
    if [ -f "$phase_path/${NODE_OS}.sh" ]; then
        bash "$phase_path/${NODE_OS}.sh"
    else
        echo "[SKIP] No specific script found for $NODE_OS in $phase_name."
    fi
}

# 🚀 Launching the Pipeline
# -----------------------------------------------------------------------------
run_phase "$SCRIPT_DIR/00_bootstrap/00_provision_vm"
run_phase "$SCRIPT_DIR/00_bootstrap/02_tabula_rasa"
run_phase "$SCRIPT_DIR/00_bootstrap/01_prepare_os"
run_phase "$SCRIPT_DIR/01_network/00_vxlan_mesh"
run_phase "$SCRIPT_DIR/01_network/01_vip_seed"
run_phase "$SCRIPT_DIR/02_datastore"
run_phase "$SCRIPT_DIR/03_engine"

# 🏗️ Platform Services (Only on PVE as the primary orchestrator)
# -----------------------------------------------------------------------------
if [ "$NODE_NAME" == "pve" ]; then
    echo "--- Phase: 04_platform (Recursive Domain Deployment) ---"
    # WHY: We traverse the domain subdirectories (core, storage, monitoring) 
    # and execute all .sh scripts in alphabetical order to respect dependencies.
    for script in $(find "$SCRIPT_DIR/04_platform" -name "*.sh" | sort); do
        echo "[Platform] Executing $(basename "$script")..."
        bash "$script"
    done
fi

echo "--- ✅ FEDERATION ENTRY COMPLETE FOR $NODE_NAME ---"
