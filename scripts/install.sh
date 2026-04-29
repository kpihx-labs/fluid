#!/bin/bash
# -----------------------------------------------------------------------------
# 🚀 MASTER INSTALLER (install.sh) - 100% AGNOSTIC & CONVENTION-BASED
# -----------------------------------------------------------------------------
# PURPOSE: Automatically sequences the construction of the entire federation.
# WHY: By following a strict naming convention ($NODE_OS.sh),
# we remove complex conditional logic and allow instant scaling to new OS types.
# -----------------------------------------------------------------------------

set -e

# 1. Path Resolution & Environment Guard
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config.env"

# 2. Sovereign Confirmation Prompt
# -----------------------------------------------------------------------------
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "⚠️  FLUID-K3S SOVEREIGN INSTALLATION : $NODE_NAME ⚠️"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "Host: $(hostname) | OS: $NODE_OS | IP: $NODE_IP"
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
    echo "--- Phase: 04_platform ---"
    bash "$SCRIPT_DIR/04_platform/longhorn.sh"
    bash "$SCRIPT_DIR/04_platform/external_secrets.sh"
fi

echo "--- ✅ FEDERATION ENTRY COMPLETE FOR $NODE_NAME ---"
