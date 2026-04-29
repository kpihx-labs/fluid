#!/bin/bash
# -----------------------------------------------------------------------------
# 🚀 ENGINE > LINUX (linux.sh - Role Aware)
# -----------------------------------------------------------------------------
# PURPOSE: Installs K3s and federates the node based on its role.
# WHY: In a 100% decentralized mesh, every node points to its local 
# CockroachDB instance via Kine. This ensures that the Control Plane 
# remains active even if other peers are offline.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

run_privileged() { $SUDO_CMD "$@"; }

MODE=${1:-"server-join"}
echo "--- 🚀 ENGINE DEPLOYMENT ($NODE_NAME - Role: $NODE_ROLE - Mode: $MODE) ---"

# 1. Datastore Resolution
# -----------------------------------------------------------------------------
if [ "$NODE_ROLE" == "master" ]; then
    # WHY: Masters always talk to their local CockroachDB for maximum resilience.
    export K3S_DATASTORE_ENDPOINT="postgres://$DB_USER@127.0.0.1:$DB_PORT/$DB_NAME?sslmode=disable"
else
    # WHY: Minions need to reach one of the Masters. We use the first Master in the list for simplicity.
    MASTER_IP=$(echo $(get_db_join_list) | cut -d',' -f1)
    export K3S_DATASTORE_ENDPOINT="postgres://$DB_USER@$MASTER_IP:$DB_PORT/$DB_NAME?sslmode=disable"
fi

# 2. Engine Configuration Flags
# -----------------------------------------------------------------------------
# --flannel-iface: Use Tailscale for zero-trust inter-node traffic.
# --node-ip: The static internal overlay IP from hosts.json.
# --tls-san: Ensure the API server is reachable via the Cluster VIP.
# --advertise-address: The VIP for cluster-wide reachability.
COMMON_FLAGS="--flannel-iface=$VXLAN_UNDERLAY_INTERFACE --node-name=$NODE_NAME --token=$K3S_TOKEN --disable traefik --disable servicelb"

# 3. Installation Execution
# -----------------------------------------------------------------------------
echo "[Action] Downloading and launching K3s ($K3S_VERSION)..."
curl -sfL https://get.k3s.io | INSTALL_K3S_VERSION="$K3S_VERSION" sh -s - server \
    $COMMON_FLAGS \
    --node-ip="$NODE_VXLAN_IP" \
    --tls-san="$CLUSTER_VIP" \
    --advertise-address="$CLUSTER_VIP"

echo "--- ✅ K3S ENGINE IS ONLINE ($NODE_ROLE FEDERATED) ---"
