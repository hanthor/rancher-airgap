#!/usr/bin/env bash
# deploy-k3s-ess-macos.sh
# Deploy ESS on macOS using Rancher Desktop
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
HAULER_BIN="./hauler.bin"
source "$SCRIPT_DIR/airgap-lib.sh"
source "$SCRIPT_DIR/hauler-functions.sh"

# Extract stores if not present
for f in k3s.tar.zst ess.tar.zst helm.tar.zst macos.tar.zst; do
  store_name="$(basename "$f" .tar.zst)-store"
  target_store="$REPO_ROOT/hauler/$store_name"
  if [ -f "$SCRIPT_DIR/$f" ] && [ ! -d "$target_store" ]; then
    mkdir -p "$target_store"
    "$SCRIPT_DIR/$HAULER_BIN" store load --filename "$SCRIPT_DIR/$f" --store "$target_store"
  fi
done

# Start services
start_hauler_registry 5002 "$REPO_ROOT/hauler/ess-store" "$REPO_ROOT/hauler/ess-store" "/tmp/ess-registry.log" "/tmp/ess-registry.pid"
start_hauler_fileserver 8081 "$REPO_ROOT/hauler/helm-store" "$REPO_ROOT/hauler/helm-store" "/tmp/helm-fileserver.log" "/tmp/helm-fileserver.pid" "$REPO_ROOT/hauler/helm-store"
start_hauler_fileserver 8080 "$REPO_ROOT/hauler/k3s-store" "$REPO_ROOT/hauler/k3s-store" "/tmp/k3s-fileserver.log" "/tmp/k3s-fileserver.pid" "$REPO_ROOT/hauler/k3s-store"
start_hauler_fileserver 8082 "$REPO_ROOT/hauler/macos-store" "$REPO_ROOT/hauler/macos-store" "/tmp/macos-fileserver.log" "/tmp/macos-fileserver.pid" "$REPO_ROOT/hauler/macos-store"

# macOS K3s install step
cat <<MACOS_INSTRUCTIONS

==== Rancher Desktop/K3s macOS Airgap Deployment ====
1. Download Rancher Desktop, kubectl, and k9s from http://localhost:8082
2. Install Rancher Desktop (mount DMG, copy to /Applications)
3. Open Rancher Desktop and set Registry Mirror to http://localhost:5002
4. Install kubectl and k9s (move to /usr/local/bin)
5. Use kubectl to verify K3s cluster is running
6. Continue ESS deployment as normal
========================================
MACOS_INSTRUCTIONS

# Continue with ESS deployment (if possible)
deploy_ess "ess.local" "$ESS_CHART_VERSION" 5002 "$REPO_ROOT/hauler/ess-helm/rancher-airgap-ess-helm.yaml" "/tmp/ess-deploy.log" "$REPO_ROOT"
validate_ess_deployment "ess.local" "$K3S_VERSION" "$ESS_CHART_VERSION" "$ARCH"
