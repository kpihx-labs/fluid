#!/bin/bash
# -----------------------------------------------------------------------------
# 💀 MASTER PURGE ORCHESTRATOR (purge.sh) - 100% AGNOSTIC
# -----------------------------------------------------------------------------
# PURPOSE: Automatically detects the host OS and triggers a 100% radical purge.
# WHY: Follows the $NODE_OS.sh convention in the 99_purge directory.
# -----------------------------------------------------------------------------

set -e
# 1. Identity & Path Resolution
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_NODE=$1

if [ -z "$TARGET_NODE" ]; then
    echo "[ERROR] Usage: ./purge.sh <NODE_NAME> (must match hosts.json)"
    exit 1
fi

source "$SCRIPT_DIR/../config.env"

# 2. Identity Guard (Anti-Accidental Wipe)
# -----------------------------------------------------------------------------
if [ "$NODE_NAME" != "$TARGET_NODE" ]; then
    echo "[ERROR] Identity Mismatch! You are trying to purge '$TARGET_NODE' but this host is detected as '$NODE_NAME'."
    exit 1
fi

# Check IP for extra safety
REAL_TS_IP=$(ip -4 addr show tailscale0 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' || echo "UNKNOWN")
if [ "$REAL_TS_IP" != "$NODE_IP" ]; then
    echo "[ERROR] IP Guard! Purge aborted. tailscale0 IP mismatch."
    exit 1
fi

# 3. Sovereign Confirmation Prompt
# -----------------------------------------------------------------------------
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "⚠️  NUCLEAR PURGE ON $NODE_NAME ($NODE_OS) ⚠️"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
read -p "Confirm radical wipe? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[yY]$ ]]; then
    echo "[ABORT] Cancelled."
    exit 0
fi

# 2. Execution (Convention-Based)
# -----------------------------------------------------------------------------
if [ -f "$SCRIPT_DIR/99_purge/${NODE_OS}.sh" ]; then
    bash "$SCRIPT_DIR/99_purge/${NODE_OS}.sh"
else
    echo "[ERROR] No purge implementation found for $NODE_OS."
    exit 1
fi

echo "--- ✅ PURGE COMPLETE FOR $NODE_NAME ---"
