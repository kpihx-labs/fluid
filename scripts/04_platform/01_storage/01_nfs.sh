#!/bin/bash
# -----------------------------------------------------------------------------
# 📦 PLATFORM > STORAGE > 01_NFS (01_nfs.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Deploys the Sovereign NFS Provisioner.
# WHY: Allows multiple pods to share the same file storage (ReadWriteMany).
# Good for shared assets and cluster-wide backups.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../config.env"

echo "--- 📦 DEPLOYING SOVEREIGN NFS PROVISIONER ---"

# WHY: Declarative approach. 
if [ -f "$SCRIPT_DIR/../../../manifests/04_platform/01_storage/nfs.yaml" ]; then
    kubectl apply -f "$SCRIPT_DIR/../../../manifests/04_platform/01_storage/nfs.yaml"
else
    echo "[SKIP] nfs.yaml not found in manifests/04_platform/01_storage/"
fi

echo "--- ✅ NFS PROVISIONER DEPLOYMENT INITIATED ---"
