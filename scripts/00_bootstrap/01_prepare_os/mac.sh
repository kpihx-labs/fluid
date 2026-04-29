#!/bin/bash
# -----------------------------------------------------------------------------
# 🔧 BOOTSTRAP > 01_PREPARE_OS > MAC (mac.sh)
# -----------------------------------------------------------------------------
# PURPOSE: Installs management tools on macOS.
# -----------------------------------------------------------------------------

set -e

# 1. Path Resolution & Configuration Loading
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../../config.env"

echo "--- 🔧 STARTING HYPER-DOCUMENTED OS PREPARATION (MAC) ---"

# 2. Package Manager Check (Homebrew)
if ! command -v brew &> /dev/null; then
    echo "[Step 1] Homebrew missing. Please install it from https://brew.sh/"
    exit 1
fi

# 3. Dependencies Installation
echo "[Step 2] Installing management tools via Homebrew..."
brew install kubernetes-cli helm jq wget curl arping || true

echo "--- ✅ MAC PREPARATION COMPLETE ---"
