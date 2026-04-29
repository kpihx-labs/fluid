#!/bin/bash
# -----------------------------------------------------------------------------
# 📦 PLATFORM > CORE > 02_KEDA (02_keda.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Installs KEDA for "Sleep Strategy" (Scale-to-0).
# WHY: To keep the cluster hyper-lean, non-used services must consume 0 resources.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../config.env"

echo "--- 📦 INSTALLING KEDA AUTO-SCALER ---"

if ! command -v helm &> /dev/null; then
    echo "[ERROR] Helm not found. Please run prepare_os first."
    exit 1
fi

helm repo add kedacore https://kedacore.github.io/charts || true
helm repo update
helm upgrade --install keda kedacore/keda \
    --namespace keda --create-namespace \
    --version "$KEDA_VERSION"

echo "--- ✅ KEDA IS ONLINE ---"
