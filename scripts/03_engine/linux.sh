#!/bin/bash
# -----------------------------------------------------------------------------
# 🚀 ENGINE > LINUX (linux.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Installs K3s and federates the node into the sovereign cluster.
# WHY: In a 100% decentralized mesh, every node points to its local 
# CockroachDB instance via Kine. This ensures that the Control Plane 
# remains active even if other peers are offline.
# -----------------------------------------------------------------------------

set -e

# 1. Path Resolution & Configuration Loading
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

run_privileged() { $SUDO_CMD "$@"; }

# 2. Context Determination
# -----------------------------------------------------------------------------
# WHY: In a decentralized mesh, we don't distinguish between 'init' and 'join' 
# for the database part (Cockroach handles it), but for K3s, the first node 
# typically provides the token if not already shared.
MODE=${1:-"server-join"}

echo "--- 🚀 STARTING HYPER-DOCUMENTED DECENTRALIZED ENGINE DEPLOYMENT ($MODE) ---"

# 3. Datastore Resolution (Kine + Local Cockroach)
# -----------------------------------------------------------------------------
# WHY: We point K3s to the LOCAL CockroachDB node. Each node is a master.
# The credentials match the insecure setup (root).
export K3S_DATASTORE_ENDPOINT="postgres://$DB_USER@127.0.0.1:$DB_PORT/$DB_NAME?sslmode=disable"

# 4. Engine Configuration Flags
# -----------------------------------------------------------------------------
# --flannel-iface: Use Tailscale for zero-trust inter-node traffic.
# --node-ip: The static internal overlay IP from hosts.json.
COMMON_FLAGS="--flannel-iface=$VXLAN_UNDERLAY_INTERFACE --node-name=$NODE_NAME --token=$K3S_TOKEN --disable traefik --disable servicelb"

# 5. Engine Installation Execution
# -----------------------------------------------------------------------------
echo "[Action] Downloading and launching K3s ($K3S_VERSION)..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server \
    $COMMON_FLAGS \
    --node-ip="$NODE_VXLAN_IP" \
    --tls-san="$CLUSTER_VIP" \
    --advertise-address="$CLUSTER_VIP"

echo "--- ✅ K3S ENGINE IS ONLINE: NODE '$NODE_NAME' FEDERATED VIA $NODE_VXLAN_IP ---"
