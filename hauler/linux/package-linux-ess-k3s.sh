#!/usr/bin/env bash
# package-airgap-ess-fixed.sh
# Clean packager: Build all Hauler stores and package for airgap deployment

set -euo pipefail

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$CURRENT_DIR/../../scripts" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
source "$SCRIPT_DIR/airgap-lib.sh"

# Configurable variables
ARCH="$(uname -m)"
LOG_DIR="/tmp/airgap-package-logs"
PACKAGE_DIR="$REPO_ROOT/.build/linux"
DEPLOY_SCRIPT_NAME="deploy.sh"
HAULER_BIN_NAME="hauler.bin"

function main() {
    check_root
    check_prerequisites "build"
    setup_directories "$PACKAGE_DIR" "$LOG_DIR"

  echo "Syncing all Hauler stores..."
  hauler store sync --store linux-store --filename "$REPO_ROOT/hauler/linux/linux-ess-k3s.yaml"


  echo "Saving Hauler stores to archives..."
  cd "$REPO_ROOT/hauler/linux"
  hauler store save --store linux-store --filename "$PACKAGE_DIR/linux.tar.zst"

  echo "Copying Hauler binary..."
  cp "$(command -v hauler)" "$PACKAGE_DIR/$HAULER_BIN_NAME"

  echo "Copy in deploy script..."
  cp "$REPO_ROOT/hauler/linux/deploy-linux-ess-k3s.sh" "$PACKAGE_DIR/$DEPLOY_SCRIPT"
  chmod +x "$PACKAGE_DIR/$DEPLOY_SCRIPT"

  echo "Copying function libraries..."
  cp "$SCRIPT_DIR/airgap-lib.sh" "$PACKAGE_DIR/airgap-lib.sh"
  cp "$SCRIPT_DIR/hauler-functions.sh" "$PACKAGE_DIR/hauler-functions.sh"

  TAR_NAME="airgap-linux-ess-k3s.tar.gz"
  tar --exclude="$TAR_NAME" -czf "$TAR_NAME" .
  echo "Tarball created: $PACKAGE_DIR/$TAR_NAME"
}

main "$@"
