#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
HAULER_BIN="./hauler.bin"
source "$SCRIPT_DIR/airgap-lib.sh"
source "$SCRIPT_DIR/hauler-functions.sh"

# Extract stores if not present
for f in linux.tar.zst; do
  store_name="$(basename "$f" .tar.zst)-store"
  target_store="$REPO_ROOT/hauler/$store_name"
  if [ -f "$SCRIPT_DIR/$f" ] && [ ! -d "$target_store" ]; then
    mkdir -p "$target_store"
    # load the archive into the intended store path
    "$SCRIPT_DIR/$HAULER_BIN" store load --filename "$SCRIPT_DIR/$f" --store "$target_store"
  fi
done

# Start services and deploy ESS
start_hauler_registry 5002 "$REPO_ROOT/hauler/linux-store" "$REPO_ROOT/hauler/linux-store" "/tmp/registry.log" "/tmp/registry.pid"
start_hauler_fileserver 8080 "$REPO_ROOT/hauler/linux-store" "$REPO_ROOT/hauler/linux-store" "/tmp/fileserver.log" "/tmp/fileserver.pid" "$REPO_ROOT/hauler/linux-store"

deploy_ess "ess.local" "$ESS_CHART_VERSION" 5002 "$REPO_ROOT/hauler/linux/linux-ess-k3s.yaml" "/tmp/ess-deploy.log" "$REPO_ROOT"
validate_ess_deployment "ess.local" "$K3S_VERSION" "$ESS_CHART_VERSION" "$ARCH"