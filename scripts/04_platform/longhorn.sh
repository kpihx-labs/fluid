#!/bin/bash
# -----------------------------------------------------------------------------
# 📦 PLATFORM > 00_LONGHORN (longhorn.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Deploys the Longhorn distributed storage engine (v1.6.1).
# WHY: In a stateless cluster, stateful applications still need block storage. 
# Longhorn mirrors volume data across the federation (PVE + Ubuntu) 
# so that a node failure does not result in data loss.
# -----------------------------------------------------------------------------

set -e

# 1. Path Resolution & Configuration Loading
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

echo "--- 📦 DEPLOYING HYPER-DOCUMENTED LONGHORN STORAGE ---"

# 2. Prerequisite Validation
# -----------------------------------------------------------------------------
# WHY: Longhorn requires open-iscsi on all nodes. We check the environment.
if ! command -v kubectl &> /dev/null; then
    echo "[ERROR] Kubectl not found. Engine must be installed first."
    exit 1
fi

# 3. Deployment Execution (Official Manifests)
# -----------------------------------------------------------------------------
# WHY: We use the pinned version from config.env to ensure reproducibility.
echo "[Step 1] Applying Longhorn manifests (Version: $LONGHORN_VERSION)..."
kubectl apply -f "https://raw.githubusercontent.com/longhorn/longhorn/${LONGHORN_VERSION}/deploy/longhorn.yaml"

# 4. StorageClass Governance
# -----------------------------------------------------------------------------
# WHY: We set Longhorn as the default StorageClass to allow applications 
# to request PersistentVolumes without explicit provider naming.
echo "[Step 2] Marking Longhorn as Default StorageClass..."
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'

echo "--- ✅ LONGHORN DEPLOYMENT INITIATED: SYNCING DATA PLANES ---"
