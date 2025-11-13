#!/usr/bin/env bash
# run-e2e-fixed.sh
# End-to-end: package assets (fixed packager), extract package, run deploy script from package

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_SCRIPT="$SCRIPT_DIR/package-airgap-ess-fixed.sh"
PACKAGE_DIR="/tmp/airgap-ess-package"
ZIP_NAME="Airgap-ess.zip"
TAR_NAME="Airgap-ess.tar.gz"
EXTRACT_DIR="/tmp/airgap-ess-extract-$(date +%s)"

function main() {
    echo "Running packager (fixed)..."
    sudo "$PACKAGE_SCRIPT"

    # Prefer zip, fall back to tarball
    if [ -f "$PACKAGE_DIR/$ZIP_NAME" ]; then
        PACKAGE_PATH="$PACKAGE_DIR/$ZIP_NAME"
        mkdir -p "$EXTRACT_DIR"
        unzip -q "$PACKAGE_PATH" -d "$EXTRACT_DIR"
    elif [ -f "$PACKAGE_DIR/$TAR_NAME" ]; then
        PACKAGE_PATH="$PACKAGE_DIR/$TAR_NAME"
        mkdir -p "$EXTRACT_DIR"
        tar -xzf "$PACKAGE_PATH" -C "$EXTRACT_DIR"
    else
        echo "No package found in $PACKAGE_DIR (expected $ZIP_NAME or $TAR_NAME)"
        exit 1
    fi

    echo "Making deploy script executable and running it from extracted folder"
    chmod +x "$EXTRACT_DIR/deploy-k3s-ess.sh"

    # Run the deploy script; it contains references to the local hauler binary and libs
    sudo "$EXTRACT_DIR/deploy-k3s-ess.sh"

    echo "End-to-end package+deploy completed."
    echo "If you want to clean up extracted files: rm -rf $EXTRACT_DIR $PACKAGE_DIR"
}

main "$@"
