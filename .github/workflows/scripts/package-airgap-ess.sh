#!/usr/bin/env bash
# package-airgap-ess-fixed.sh
# Clean packager: Build all Hauler stores and package for airgap deployment

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/../../.."
source "$SCRIPT_DIR/airgap-lib.sh"

# Configurable variables
ARCH="$(uname -m)"
LOG_DIR="/tmp/airgap-package-logs"
PACKAGE_DIR="/tmp/airgap-ess-package"
ZIP_NAME="Airgap-ess.zip"
DEPLOY_SCRIPT="deploy-k3s-ess.sh"
HAULER_BIN_NAME="hauler.bin"

function main() {
    check_root
    check_prerequisites "build"
    setup_directories "$PACKAGE_DIR" "$LOG_DIR"

    echo "Building all Hauler stores..."
    build_all_hauler_stores "$REPO_ROOT" "$ARCH" "$LOG_DIR"

    echo "Saving Hauler stores to archives..."
    cd "$REPO_ROOT/hauler/k3s"
    hauler store save --store k3s-store --filename "$PACKAGE_DIR/k3s.tar.zst"
    cd "$REPO_ROOT/hauler/ess-helm"
    hauler store save --store ess-store --filename "$PACKAGE_DIR/ess.tar.zst"
    cd "$REPO_ROOT/hauler/helm"
    hauler store save --store helm-store --filename "$PACKAGE_DIR/helm.tar.zst"

    echo "Copying Hauler binary..."
    cp "$(command -v hauler)" "$PACKAGE_DIR/$HAULER_BIN_NAME"

    # Include any Windows Rancher Desktop installer or Windows hauler binary if present
    if [ -d "$REPO_ROOT/hauler/windows" ]; then
      echo "Including Windows artifacts from $REPO_ROOT/hauler/windows"
      mkdir -p "$PACKAGE_DIR/hauler/windows"
      cp -r "$REPO_ROOT/hauler/windows/"* "$PACKAGE_DIR/hauler/windows/" || true
    fi

    echo "Creating deploy script..."
    cat > "$PACKAGE_DIR/$DEPLOY_SCRIPT" <<'EODEP'
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
HAULER_BIN="./hauler.bin"
source "$SCRIPT_DIR/airgap-lib.sh"
source "$SCRIPT_DIR/hauler-functions.sh"

# Extract stores if not present
for f in k3s.tar.zst ess.tar.zst helm.tar.zst; do
  store_name="$(basename "$f" .tar.zst)-store"
  target_store="$REPO_ROOT/hauler/$store_name"
  if [ -f "$SCRIPT_DIR/$f" ] && [ ! -d "$target_store" ]; then
    mkdir -p "$target_store"
    # load the archive into the intended store path
    "$SCRIPT_DIR/$HAULER_BIN" store load --filename "$SCRIPT_DIR/$f" --store "$target_store"
  fi
done

# Start services and deploy ESS
start_hauler_registry 5002 "$REPO_ROOT/hauler/ess-store" "$REPO_ROOT/hauler/ess-store" "/tmp/ess-registry.log" "/tmp/ess-registry.pid"
start_hauler_fileserver 8081 "$REPO_ROOT/hauler/helm-store" "$REPO_ROOT/hauler/helm-store" "/tmp/helm-fileserver.log" "/tmp/helm-fileserver.pid" "$REPO_ROOT/hauler/helm-store"
start_hauler_fileserver 8080 "$REPO_ROOT/hauler/k3s-store" "$REPO_ROOT/hauler/k3s-store" "/tmp/k3s-fileserver.log" "/tmp/k3s-fileserver.pid" "$REPO_ROOT/hauler/k3s-store"

deploy_ess "ess.local" "$ESS_CHART_VERSION" 5002 "$REPO_ROOT/hauler/ess-helm/rancher-airgap-ess-helm.yaml" "/tmp/ess-deploy.log" "$REPO_ROOT"
validate_ess_deployment "ess.local" "$K3S_VERSION" "$ESS_CHART_VERSION" "$ARCH"
EODEP
    chmod +x "$PACKAGE_DIR/$DEPLOY_SCRIPT"

    echo "Copying function libraries..."
    cp "$SCRIPT_DIR/airgap-lib.sh" "$PACKAGE_DIR/airgap-lib.sh"
    cp "$SCRIPT_DIR/hauler-functions.sh" "$PACKAGE_DIR/hauler-functions.sh"

  # Create a Windows deploy helper (PowerShell) if Windows artifacts were included
  if [ -d "$PACKAGE_DIR/hauler/windows" ]; then
    cat > "$PACKAGE_DIR/deploy-windows-rd.ps1" <<'EOPS'
# Deploy Rancher Desktop & configure air-gapped K3s (Windows helper)
# This script is intended as a guided helper. It will attempt to run the
# Rancher Desktop installer if one is packaged and will print the recommended
# post-install configuration steps following the Rancher Desktop air-gapped
# guidance: https://docs.rancherdesktop.io/how-to-guides/running-air-gapped/

param(
  [switch]$InstallSilently
)

Write-Host "Rancher Desktop Windows deploy helper"

$pkgPath = Join-Path -Path $PSScriptRoot -ChildPath 'hauler/windows'
Get-ChildItem -Path $pkgPath -File | ForEach-Object { Write-Host "Found: $($_.Name)" }

# Find an installer (exe or msi)
$installer = Get-ChildItem -Path $pkgPath -Include *.exe,*.msi -File -ErrorAction SilentlyContinue | Select-Object -First 1
if ($null -eq $installer) {
  Write-Host "No Rancher Desktop installer found in $pkgPath. Please copy the installer to that folder and re-run."
  exit 1
}

Write-Host "Installer: $($installer.FullName)"
if ($InstallSilently) {
  Write-Host "Running installer silently (may require specific vendor args)..."
  if ($installer.Extension -ieq '.msi') {
    Start-Process msiexec -ArgumentList "/i `"$($installer.FullName)`" /qn" -Wait -NoNewWindow
  } else {
    # Many Rancher Desktop installers are interactive; check vendor docs for silent flags
    Start-Process -FilePath $installer.FullName -ArgumentList "/S" -Wait -NoNewWindow
  }
} else {
  Write-Host "Please run the installer interactively: $($installer.FullName)"
}

Write-Host "\nAfter installing Rancher Desktop, follow these recommended steps (see docs):"
Write-Host " 1) Open Rancher Desktop -> Settings -> Kubernetes and select the k3s runtime."
Write-Host " 2) Ensure the container runtime is configured to use containerd (default)."
Write-Host " 3) Configure a local registry mirror pointing to the packaged Hauler registry."
Write-Host "    - Example: add http://localhost:5002 as an insecure registry/mirror in Rancher Desktop settings"
Write-Host " 4) Use docker / nerdctl inside Rancher Desktop to load any images or charts as needed."
Write-Host " 5) To load Hauler stores into a local registry, extract the package on Windows and run the included hauler binary for Windows (if provided) or follow the hauler docs."

Write-Host "Notes:"
Write-Host " - This helper does not automatically reconfigure Rancher Desktop for every Windows version; consult the upstream guide: https://docs.rancherdesktop.io/how-to-guides/running-air-gapped/"
Write-Host " - If you want automation for modifying Rancher Desktop settings.json, please share your target Windows versions and I can add registry-safe edits."
EOPS
    chmod +x "$PACKAGE_DIR/deploy-windows-rd.ps1" || true
  fi

    echo "Packaging everything into $ZIP_NAME..."
    cd "$PACKAGE_DIR"
  if command -v zip >/dev/null 2>&1; then
    zip -r "$ZIP_NAME" *
    echo "Package created: $PACKAGE_DIR/$ZIP_NAME"
  else
    TAR_NAME="Airgap-ess.tar.gz"
    # exclude the tarball itself if it exists in the directory
    tar --exclude="$TAR_NAME" -czf "$TAR_NAME" .
    echo "zip not found; created tarball: $PACKAGE_DIR/$TAR_NAME"
  fi
  # Also create a tarball for portability (ensure we exclude the tarball itself)
  TAR_NAME="Airgap-ess.tar.gz"
  tar --exclude="$TAR_NAME" -czf "$TAR_NAME" .
  echo "Tarball created: $PACKAGE_DIR/$TAR_NAME"
}

main "$@"
