#!/bin/bash
# -----------------------------------------------------------------------------
# 📦 PLATFORM > STORAGE > 00_LONGHORN (00_longhorn.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Deploys the Longhorn distributed storage engine.
# WHY: In a stateless cluster, stateful applications still need block storage. 
# Longhorn mirrors volume data across the federation (PVE + Ubuntu) 
# so that a node failure does not result in data loss.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../config.env"

echo "--- 📦 DEPLOYING LONGHORN STORAGE ---"

# WHY: Longhorn requires open-iscsi on all nodes. We check the environment.
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] Kubectl not found. Engine must be installed first."
    exit 1
fi

# WHY: We use the pinned version from config.env to ensure reproducibility.
echo "[Action] Applying Longhorn manifests (Version: $LONGHORN_VERSION)..."
kubectl apply -f "https://raw.githubusercontent.com/longhorn/longhorn/${LONGHORN_VERSION}/deploy/longhorn.yaml"

# WHY: We set Longhorn as the default StorageClass.
echo "[Action] Marking Longhorn as Default StorageClass..."
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' || echo "[WARNING] Could not patch StorageClass. May already be default or not ready yet."

echo "--- ✅ LONGHORN DEPLOYMENT INITIATED ---"
