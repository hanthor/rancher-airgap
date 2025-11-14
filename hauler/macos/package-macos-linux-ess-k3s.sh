#!/usr/bin/env bash
# package-airgap-ess-macos.sh
# Packager for airgap deployment (includes macOS store)

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$CURRENT_DIR/../../scripts" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
source "$SCRIPT_DIR/airgap-lib.sh"

ARCH="$(uname -m)"
LOG_DIR="/tmp/airgap-package-logs"
PACKAGE_DIR="$REPO_ROOT/.build/macos"
DEPLOY_SCRIPT_NAME="deploy.sh"
HAULER_BIN_NAME="hauler.bin"

function main() {
    check_root
    check_prerequisites "build"
    setup_directories "$PACKAGE_DIR" "$LOG_DIR"

  echo "Syncing all Hauler store..."
  hauler store sync --store macos-store --filename "$REPO_ROOT/hauler/macos/rancher-airgap-macos.yaml"

  echo "Saving Hauler store to archives..."
  cd "$REPO_ROOT/hauler/macos"
  hauler store save --store macos-store --filename "$PACKAGE_DIR/macos.tar.zst"

    echo "Copying Hauler binary..."
    cp "$(command -v hauler)" "$PACKAGE_DIR/$HAULER_BIN_NAME"

    echo "Creating deploy script..."
    cat > "$PACKAGE_DIR/$DEPLOY_SCRIPT" <<'EODEP'

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
