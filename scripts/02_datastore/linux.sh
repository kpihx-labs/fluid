#!/bin/bash
# -----------------------------------------------------------------------------
# 🧠 DATASTORE > LINUX (CockroachDB Mesh)
# -----------------------------------------------------------------------------
# PURPOSE: Deploys a Lean CockroachDB node to form a distributed SQL mesh.
# WHY: In a 100% decentralized cluster, the state layer MUST be multi-master.
# CockroachDB ensures that if any node falls, the cluster continues with 
# 100% data integrity. We optimize for low resource usage (Lean Mode).
# -----------------------------------------------------------------------------

set -e

# 1. Environment Loading
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

run_privileged() { $SUDO_CMD "$@"; }

echo "--- 🧠 INITIALIZING LEAN COCKROACH MESH NODE ($NODE_NAME) ---"

# 2. Binary Installation
# -----------------------------------------------------------------------------
# WHY: We use the official binary for maximum stability and performance.
if ! command -v cockroach &> /dev/null; then
    echo "[Step 1] Installing CockroachDB $COCKROACH_VERSION..."
    curl https://binaries.cockroachdb.com/cockroach-${COCKROACH_VERSION}.linux-amd64.tgz | tar -xz
    run_privileged cp -i cockroach-${COCKROACH_VERSION}.linux-amd64/cockroach /usr/local/bin/
    rm -rf cockroach-${COCKROACH_VERSION}.linux-amd64
fi

# 3. Lean Configuration & Data Directories
# -----------------------------------------------------------------------------
# WHY: We restrict cache and memory to keep the host "silent" and responsive.
mkdir -p "$HOME/cockroach-data"
JOIN_LIST=$(get_db_join_list)

# 4. Service Launch (Insecure Mesh for Sovereign Internal Network)
# -----------------------------------------------------------------------------
# WHY: We use '--insecure' because we are already inside the Tailscale 
# encrypted mesh. This simplifies management without sacrificing security.
# '--cache=128Mi' and '--max-sql-memory=128Mi' ensure minimal RAM footprint.
echo "[Step 2] Launching CockroachDB Peer (Joining: $JOIN_LIST)..."
run_privileged pkill -9 cockroach || true

# WHY: We run it as a background process. For prod, we'll use a systemd unit.
nohup cockroach start \
    --insecure \
    --store="$HOME/cockroach-data" \
    --listen-addr="$NODE_IP:$DB_PORT" \
    --http-addr="$NODE_IP:$DB_HTTP_PORT" \
    --join="$JOIN_LIST" \
    --cache=128Mi \
    --max-sql-memory=128Mi \
    --background > "$HOME/cockroach.log" 2>&1

# 5. Initialization (Only on the first node)
# -----------------------------------------------------------------------------
# WHY: One node must trigger the 'init' to form the cluster.
if [ "$NODE_NAME" == "pve" ]; then
    echo "[Step 3] Initializing the State Mesh..."
    sleep 5
    cockroach init --insecure --host="$NODE_IP" || true
fi

# 6. Database & User Provisioning
# -----------------------------------------------------------------------------
echo "[Step 4] Creating K3s state schema..."
sleep 5
cockroach sql --insecure --host="$NODE_IP" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;" || true

echo "--- ✅ STATE MESH NODE IS ONLINE ---"
