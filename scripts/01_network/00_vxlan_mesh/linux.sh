#!/bin/bash
# -----------------------------------------------------------------------------
# 🌐 NETWORK > 00_VXLAN_MESH > LINUX (linux.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Creates a Layer 2 overlay network on top of the Tailscale L3 mesh.
# WHY: In a 100% decentralized mesh, we use NODE_VXLAN_IP from hosts.json
# to ensure each node has its unique address in the shared broadcast domain.
# -----------------------------------------------------------------------------

set -e

# 1. Path Resolution & Configuration Loading
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../config.env"

run_privileged() { $SUDO_CMD "$@"; }

echo "--- 🌐 INITIALIZING HYPER-DOCUMENTED VXLAN TUNNEL ---"

# 2. Local IP Detection (Tailscale Binding)
# -----------------------------------------------------------------------------
# WHY: We MUST bind the VXLAN 'local' endpoint to the Tailscale interface IP.
LOCAL_IP=$(ip -4 addr show dev "$VXLAN_UNDERLAY_INTERFACE" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')

if [ -z "$LOCAL_IP" ]; then
    echo "[ERROR] Tailscale IP not found on interface $VXLAN_UNDERLAY_INTERFACE."
    exit 1
fi
echo "[INFO] Binding VXLAN to Local Tailscale IP: $LOCAL_IP"

# 3. Interface Reset
# -----------------------------------------------------------------------------
echo "[Step 1] Cleaning legacy overlay interfaces..."
run_privileged ip link delete "$CLUSTER_INTERFACE" 2>/dev/null || true

# 4. VXLAN Tunnel Creation
# -----------------------------------------------------------------------------
echo "[Step 2] Creating VXLAN interface $CLUSTER_INTERFACE (ID: $VXLAN_ID)..."
run_privileged ip link add "$CLUSTER_INTERFACE" type vxlan \
    id "$VXLAN_ID" \
    local "$LOCAL_IP" \
    dev "$VXLAN_UNDERLAY_INTERFACE" \
    dstport "$VXLAN_PORT" \
    nolearning

# 5. MTU & Link Activation
# -----------------------------------------------------------------------------
echo "[Step 3] Configuring MTU $VXLAN_MTU and activating link..."
run_privileged ip link set "$CLUSTER_INTERFACE" mtu "$VXLAN_MTU"
run_privileged ip link set "$CLUSTER_INTERFACE" up

# 6. Overlay IP Assignment (Inventory-Based)
# -----------------------------------------------------------------------------
# WHY: We use the IP from hosts.json for 100% agnosticism.
echo "[Step 4] Assigning Overlay IP: $NODE_VXLAN_IP/24..."
run_privileged ip addr add "$NODE_VXLAN_IP/24" dev "$CLUSTER_INTERFACE"

echo "--- ✅ VXLAN OVERLAY IS ONLINE: REACHABLE AT $NODE_VXLAN_IP ---"
