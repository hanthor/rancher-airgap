#!/bin/bash
# Deploy Airgap Environment Script
# Deploys K3s + ESS from existing Hauler stores (Distribution phase only)
#
# Usage: sudo ./deploy-airgap.sh [OPTIONS]
#
# This script runs on a DISCONNECTED system using pre-built Hauler stores

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/.github/workflows/config"

# Source the airgap function library
source "$SCRIPT_DIR/airgap-lib.sh"
source "$SCRIPT_DIR/hauler-functions.sh"

# Default configuration
K3S_VERSION="${K3S_VERSION:-v1.33.5+k3s1}"
HELM_VERSION="${HELM_VERSION:-v3.19.0}"
ESS_CHART_VERSION="${ESS_CHART_VERSION:-25.11.0}"
DOMAIN="${DOMAIN:-ess.local}"
PLATFORM="${PLATFORM:-$(uname -m)}"

# Service ports
K3S_REGISTRY_PORT=5001
ESS_REGISTRY_PORT=5002
K3S_FILESERVER_PORT=8080
HELM_FILESERVER_PORT=8081

# Directories
WORK_DIR="/tmp/airgap-deploy"
LOG_DIR="$WORK_DIR/logs"
# Default store directory now points to the repo-local .build directory
STORE_DIR="${STORE_DIR:-$REPO_ROOT/.build}"

# Detect architecture
ARCH=$(detect_architecture "$PLATFORM")

# Print functions
print_banner() {
  print_header "Deploy Airgap Environment"
  echo "Purpose: Deploy K3s + ESS from local Hauler stores"
  echo "Mode: Distribution (disconnected/airgapped)"
  echo ""
  echo "Configuration:"
  echo "  K3s Version: $K3S_VERSION"
  echo "  Helm Version: $HELM_VERSION"
  echo "  ESS Chart Version: $ESS_CHART_VERSION"
  echo "  Domain: $DOMAIN"
  echo "  Platform: linux/$ARCH"
  echo "  Store Directory: $STORE_DIR"
  echo ""
}

# Verify Hauler stores exist
verify_stores() {
  print_header "Verifying Hauler Stores"
  
  local missing_stores=()
  
  if [ ! -d "$STORE_DIR/k3s/k3s-store" ]; then
    missing_stores+=("K3s store")
  fi
  
  if [ ! -d "$STORE_DIR/ess-helm/ess-store" ]; then
    missing_stores+=("ESS store")
  fi
  
  if [ ! -d "$STORE_DIR/helm/helm-store" ]; then
    missing_stores+=("Helm store")
  fi
  
  if [ ${#missing_stores[@]} -ne 0 ]; then
    print_error "Missing required Hauler stores: ${missing_stores[*]}"
    echo ""
    echo "Run ./build-airgap-assets.sh first to create stores,"
    echo "or load from archives:"
    echo "  cd $STORE_DIR/k3s && hauler store load --filename k3s.tar.zst"
    echo "  cd $STORE_DIR/ess-helm && hauler store load --filename ess.tar.zst"
    echo "  cd $STORE_DIR/helm && hauler store load --filename helm.tar.zst"
    return 1
  fi
  
  print_success "All required Hauler stores found"
  return 0
}

# Main function
main() {
  print_banner
  
  # Check if running as root
  check_root || exit 1
  
  # Check prerequisites (deploy-only mode)
  check_prerequisites "deploy-only" || exit 1
  
  # Setup directories
  setup_directories "$WORK_DIR" "$LOG_DIR"
  
  # Verify Hauler stores exist
  verify_stores || exit 1
  
  # Configure K3s registries
  configure_k3s_registries "$CONFIG_DIR/k3s-registries.yaml" "$K3S_REGISTRY_PORT" "$ESS_REGISTRY_PORT"
  
  # Install K3s
  install_k3s_from_hauler "$REPO_ROOT" "$K3S_VERSION" "$ARCH" "$WORK_DIR" "$LOG_DIR" "$K3S_FILESERVER_PORT" || exit 1
  
  # Start Hauler services
  print_header "Starting Hauler Registry and Fileserver"
  
  # Start K3s registry
  start_hauler_registry \
    "$K3S_REGISTRY_PORT" \
    "k3s-store" \
    "$REPO_ROOT/hauler/k3s" \
    "$LOG_DIR/k3s-registry.log" \
    "$WORK_DIR/k3s-registry.pid" || exit 1
  
  # Start ESS registry
  start_hauler_registry \
    "$ESS_REGISTRY_PORT" \
    "ess-store" \
    "$REPO_ROOT/hauler/ess-helm" \
    "$LOG_DIR/ess-registry.log" \
    "$WORK_DIR/ess-registry.pid" || exit 1
  
  # Start Helm fileserver
  start_hauler_fileserver \
    "$HELM_FILESERVER_PORT" \
    "helm-store" \
    "$REPO_ROOT/hauler/helm" \
    "$LOG_DIR/helm-fileserver.log" \
    "$WORK_DIR/helm-fileserver.pid" \
    "$WORK_DIR/helm-fileserver" || exit 1
  
  # Restart K3s to pick up registry configuration
  print_step "Restarting K3s to apply registry configuration..."
  systemctl restart k3s
  sleep 10
  
  # Wait for K3s to be ready
  local retries=0
  while [ $retries -lt 30 ]; do
    if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
      print_success "K3s restarted and ready"
      break
    fi
    retries=$((retries + 1))
    sleep 2
  done
  
  print_success "All Hauler services are ready"
  
  # Install Helm
  install_helm_from_hauler "$HELM_VERSION" "$ARCH" "$HELM_FILESERVER_PORT" || exit 1
  
  # Deploy ESS
  deploy_ess "$DOMAIN" "$ESS_CHART_VERSION" "$ESS_REGISTRY_PORT" "$CONFIG_DIR" "$LOG_DIR" "$REPO_ROOT" || exit 1
  
  # Validate deployment
  validate_ess_deployment "$DOMAIN" "$K3S_VERSION" "$ESS_CHART_VERSION" "$ARCH"
  
  local exit_code=$?
  
  # Cleanup instructions
  echo ""
  print_step "Hauler services are running in the background"
  echo "To stop them: pkill -f 'hauler store serve'"
  echo "Logs available in: $LOG_DIR"
  
  exit $exit_code
}

# Run main function
main "$@"
