#!/usr/bin/env bash
# package-airgap-ess-macos.sh
# Packager for airgap deployment (includes macOS store)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
source "$SCRIPT_DIR/airgap-lib.sh"

ARCH="$(uname -m)"
LOG_DIR="/tmp/airgap-package-logs"
PACKAGE_DIR="/tmp/airgap-ess-package"
ZIP_NAME="Airgap-ess-macos.zip"
DEPLOY_SCRIPT="deploy-k3s-ess-macos.sh"
HAULER_BIN_NAME="hauler.bin"

function main() {
    check_root
    check_prerequisites "build"
    setup_directories "$PACKAGE_DIR" "$LOG_DIR"

  echo "Syncing all Hauler stores..."
  hauler store sync --store k3s-store --filename "$REPO_ROOT/hauler/k3s/rancher-airgap-k3s.yaml"
  hauler store sync --store ess-store --filename "$REPO_ROOT/hauler/ess-helm/rancher-airgap-ess-helm.yaml"
  hauler store sync --store helm-store --filename "$REPO_ROOT/hauler/helm/rancher-airgap-helm.yaml"
  hauler store sync --store macos-store --filename "$REPO_ROOT/hauler/macos/rancher-airgap-macos.yaml"

  echo "Saving Hauler stores to archives..."
  cd "$REPO_ROOT/hauler/k3s"
  hauler store save --store k3s-store --filename "$PACKAGE_DIR/k3s.tar.zst"
  cd "$REPO_ROOT/hauler/ess-helm"
  hauler store save --store ess-store --filename "$PACKAGE_DIR/ess.tar.zst"
  cd "$REPO_ROOT/hauler/helm"
  hauler store save --store helm-store --filename "$PACKAGE_DIR/helm.tar.zst"
  cd "$REPO_ROOT/hauler/macos"
  hauler store save --store macos-store --filename "$PACKAGE_DIR/macos.tar.zst"

    echo "Copying Hauler binary..."
    cp "$(command -v hauler)" "$PACKAGE_DIR/$HAULER_BIN_NAME"

    echo "Creating deploy script..."
    cat > "$PACKAGE_DIR/$DEPLOY_SCRIPT" <<'EODEP'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd \"$(dirname \"${BASH_SOURCE[0]}\")\" && pwd)"
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

# Start services and deploy ESS
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
EODEP
    chmod +x "$PACKAGE_DIR/$DEPLOY_SCRIPT"

    echo "Copying function libraries..."
    cp "$SCRIPT_DIR/airgap-lib.sh" "$PACKAGE_DIR/airgap-lib.sh"
    cp "$SCRIPT_DIR/hauler-functions.sh" "$PACKAGE_DIR/hauler-functions.sh"

    echo "Packaging everything into $ZIP_NAME..."
    cd "$PACKAGE_DIR"
    if command -v zip >/dev/null 2>&1; then
      zip -r "$ZIP_NAME" *
      echo "Package created: $PACKAGE_DIR/$ZIP_NAME"
    else
      TAR_NAME="Airgap-ess-macos.tar.gz"
      tar --exclude="$TAR_NAME" -czf "$TAR_NAME" .
      echo "zip not found; created tarball: $PACKAGE_DIR/$TAR_NAME"
    fi
    TAR_NAME="Airgap-ess-macos.tar.gz"
    tar --exclude="$TAR_NAME" -czf "$TAR_NAME" .
    echo "Tarball created: $PACKAGE_DIR/$TAR_NAME"
}

main "$@"
