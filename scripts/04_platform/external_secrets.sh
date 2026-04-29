#!/bin/bash
# -----------------------------------------------------------------------------
# 🔐 PLATFORM > 01_EXTERNAL_SECRETS (external_secrets.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Bridges the gap between Bitwarden and Kubernetes Secrets (ESO).
# WHY: Hardcoding secrets in YAML or Git is a critical security risk. 
# ESO pulls encrypted data directly from our Sovereign Vault (Bitwarden)
# and injects it as K8s Secret objects in real-time.
# -----------------------------------------------------------------------------

set -e

# 1. Path Resolution & Configuration Loading
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

echo "--- 🔐 DEPLOYING HYPER-DOCUMENTED EXTERNAL SECRETS OPERATOR ---"

# 2. Deployment Logic (Local vs Remote Manifests)
# -----------------------------------------------------------------------------
# WHY: We prefer local manifests (manifests/eso.yaml) if they exist to 
# maintain offline resilience. Otherwise, we fetch the pinned version.
echo "[Step 1] Injecting ESO manifests into the cluster..."
if [ -f "$SCRIPT_DIR/../../../manifests/eso.yaml" ]; then
    echo "[INFO] Using local Sovereign Manifest (manifests/eso.yaml)..."
    kubectl apply -f "$SCRIPT_DIR/../../../manifests/eso.yaml"
else
    echo "[INFO] Local manifest missing. Fetching version $ESO_VERSION from GitHub..."
    kubectl apply -f "https://github.com/external-secrets/external-secrets/releases/download/${ESO_VERSION}/external-secrets.yaml"
fi

echo "--- ✅ ESO DEPLOYMENT IN PROGRESS: VAULT BRIDGE ESTABLISHED ---"
