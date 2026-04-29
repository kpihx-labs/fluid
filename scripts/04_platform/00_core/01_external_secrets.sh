#!/bin/bash
# -----------------------------------------------------------------------------
# 🔐 PLATFORM > CORE > 01_EXTERNAL_SECRETS (01_external_secrets.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Bridges the gap between Bitwarden and Kubernetes Secrets (ESO).
# WHY: Hardcoding secrets in YAML or Git is a critical security risk. 
# ESO pulls encrypted data directly from our Sovereign Vault (Bitwarden)
# and injects it as K8s Secret objects in real-time.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../config.env"

echo "--- 🔐 DEPLOYING EXTERNAL SECRETS OPERATOR ---"

# WHY: We prefer local manifests to maintain offline resilience.
if [ -f "$SCRIPT_DIR/../../../manifests/04_platform/00_core/eso.yaml" ]; then
    echo "[INFO] Using local Sovereign Manifest (manifests/04_platform/00_core/eso.yaml)..."
    kubectl apply -f "$SCRIPT_DIR/../../../manifests/04_platform/00_core/eso.yaml"
else
    echo "[INFO] Local manifest missing. Fetching version $ESO_VERSION from GitHub..."
    kubectl apply -f "https://github.com/external-secrets/external-secrets/releases/download/${ESO_VERSION}/external-secrets.yaml"
fi

echo "--- ✅ ESO DEPLOYMENT IN PROGRESS: VAULT BRIDGE ESTABLISHED ---"
