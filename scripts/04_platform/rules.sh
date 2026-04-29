#!/bin/bash
# -----------------------------------------------------------------------------
# 📦 PLATFORM > 01_RULES (rules.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Deploys the Sovereign PriorityClasses (Alpha, Beta, Gamma).
# WHY: This is the 'Loi du Cluster'. It ensures vital services survive at any cost.
# -----------------------------------------------------------------------------

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../config.env"

echo "--- 📦 APPLYING SOVEREIGN PRIORITY RULES ---"

mkdir -p "$SCRIPT_DIR/../../manifests/04_platform"
cat <<EOF > "$SCRIPT_DIR/../../manifests/04_platform/priority-classes.yaml"
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: fluid-alpha
value: 1000
globalDefault: false
description: "Vital Services (Quorum, Networking, State). Cannot be evicted."
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: fluid-beta
value: 500
globalDefault: false
description: "Compute Services. Can be evicted to save Alpha services."
---
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: fluid-gamma
value: 100
globalDefault: false
description: "OS Specific / Non-critical tools. First to be evicted."
EOF

kubectl apply -f "$SCRIPT_DIR/../../manifests/04_platform/priority-classes.yaml"

echo "--- ✅ PRIORITY RULES APPLIED ---"
