#!/bin/bash
# -----------------------------------------------------------------------------
# 📦 PLATFORM > CORE > 00_RULES (00_rules.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Applies the Sovereign PriorityClasses (Alpha, Beta, Gamma).
# WHY: This is the 'Loi du Cluster'. It ensures vital services survive at any cost.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../config.env"

echo "--- 📦 APPLYING SOVEREIGN PRIORITY RULES ---"

# WHY: Declarative approach. The manifest is the source of truth.
kubectl apply -f "$SCRIPT_DIR/../../../manifests/04_platform/00_core/priority-classes.yaml"

echo "--- ✅ PRIORITY RULES APPLIED ---"
