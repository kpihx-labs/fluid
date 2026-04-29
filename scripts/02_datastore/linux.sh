#!/bin/bash
# -----------------------------------------------------------------------------
# 🧠 DATASTORE > LINUX (CockroachDB Mesh - Role Aware)
# -----------------------------------------------------------------------------
# PURPOSE: Deploys CockroachDB only on Masters.
# WHY: In a Master/Minion architecture, the state layer is managed by the 
# Core Masters. Minions don't store data but point to the Masters.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

run_privileged() { $SUDO_CMD "$@"; }

echo "--- 🧠 DATASTORE INITIALIZATION ($NODE_NAME - Role: $NODE_ROLE) ---"

if [ "$NODE_ROLE" == "master" ]; then
    # 1. Binary Installation
    if ! command -v cockroach &> /dev/null; then
        echo "[Action] Installing CockroachDB $COCKROACH_VERSION..."
        curl https://binaries.cockroachdb.com/cockroach-${COCKROACH_VERSION}.linux-amd64.tgz | tar -xz
        run_privileged cp -i cockroach-${COCKROACH_VERSION}.linux-amd64/cockroach /usr/local/bin/
        rm -rf cockroach-${COCKROACH_VERSION}.linux-amd64
    fi

    # 2. Service Launch
    mkdir -p "$HOME/cockroach-data"
    JOIN_LIST=$(get_db_join_list)
    
    echo "[Action] Launching Master Peer (Joining: $JOIN_LIST)..."
    run_privileged pkill -9 cockroach || true

    nohup cockroach start \
        --insecure \
        --store="$HOME/cockroach-data" \
        --listen-addr="$NODE_IP:$DB_PORT" \
        --http-addr="$NODE_IP:$DB_HTTP_PORT" \
        --join="$JOIN_LIST" \
        --cache=128Mi \
        --max-sql-memory=128Mi \
        --background > "$HOME/cockroach.log" 2>&1

    # 3. Initialization (Peer-to-Peer)
    # WHY: Any Master can attempt to init. Idempotent.
    echo "[Step 3] Attempting State Mesh Initialization..."
    sleep 5
    cockroach init --insecure --host="$NODE_IP" || echo "[INFO] Cluster already initialized."

    # 4. Database Schema
    cockroach sql --insecure --host="$NODE_IP" -e "CREATE DATABASE IF NOT EXISTS $DB_NAME;" || true
    echo "--- ✅ MASTER DATASTORE IS ONLINE ---"
else
    echo "--- ℹ️ NODE ROLE IS MINION: NO LOCAL DATASTORE DEPLOYED ---"
    echo "--- Minion will point to Masters: $(get_db_join_list) ---"
fi
