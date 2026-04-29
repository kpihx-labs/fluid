#!/bin/bash
# -----------------------------------------------------------------------------
# 🏗️ BOOTSTRAP > 00_PROVISION_VM > PVE (pve.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Automates the creation of a Linux VM on Proxmox to host a K3s node.
# WHY: Manual VM creation is prone to configuration drift. This script ensures
# every node follows the exact hardware specification required for HA.
# Using 'qm' (Proxmox Virtual Machine Manager) allows for reproducible IaaS.
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
# WHY: We use the SUDO_CMD and REMOTE_SUDO defined in config.env to ensure
# the script remains agnostic to the specific privilege escalation tool used.
run_privileged_remote() {
    # WHY: $REMOTE_CMD is usually 'ssh'. We execute the command on the hypervisor.
    $REMOTE_CMD "$PVE_HOST" "$REMOTE_SUDO" "$@"
}

TARGET_VM_ID=${1:-$VM_ID_START}
TARGET_VM_NAME=${2:-$VM_NAME_PREFIX}

echo "--- 🏗️ PROVISIONING VM ON PROXMOX ($TARGET_VM_NAME - ID: $TARGET_VM_ID) ---"

# Phase 1: VM Skeleton Creation
# -----------------------------------------------------------------------------
# WHY: 'qm create' initializes the VM configuration file on Proxmox.
# --net0: Connects the VM to the default Proxmox bridge (vmbr0).
# --agent 1: Enables the QEMU Guest Agent for better host-guest integration.
echo "[Step 1] Creating VM shell on host $PVE_HOST..."
run_privileged_remote qm create "$TARGET_VM_ID" \
    --name "$TARGET_VM_NAME" \
    --net0 virtio,bridge=vmbr0 \
    --ostype l26 \
    --agent 1

# Phase 2: Storage Allocation
# -----------------------------------------------------------------------------
# WHY: Defining the disk controller and allocating the OS drive.
# --scsihw virtio-scsi-pci: Optimized SCSI controller for Linux guests.
echo "[Step 2] Allocating ${VM_DISK_SIZE}GB storage on pool $PVE_STORAGE..."
run_privileged_remote qm set "$TARGET_VM_ID" \
    --scsihw virtio-scsi-pci \
    --scsi0 "${PVE_STORAGE}:${VM_DISK_SIZE},format=raw"

# Phase 3: Hardware Specification
# -----------------------------------------------------------------------------
# WHY: Setting RAM and CPU to the standardized levels defined in config.env.
# --cpu host: Passes through the physical CPU features for maximum performance.
echo "[Step 3] Setting hardware resources (Memory: ${VM_MEMORY}MB, Cores: ${VM_CORES})..."
run_privileged_remote qm set "$TARGET_VM_ID" \
    --memory "$VM_MEMORY" \
    --cores "$VM_CORES" \
    --sockets 1 \
    --cpu host

# Phase 4: Lifecycle Configuration
# -----------------------------------------------------------------------------
# WHY: Onboot ensures the VM starts automatically when the Proxmox host boots.
echo "[Step 4] Finalizing VM configuration..."
run_privileged_remote qm set "$TARGET_VM_ID" \
    --onboot 1 \
    --tablet 0

echo "--- ✅ PROVISIONING COMPLETE: VM $TARGET_VM_ID IS READY FOR OS ---"
