#!/bin/bash
# Local Airgap Test Script for K3s + ESS Deployment
# This script mirrors the GitHub Actions airgap test workflow but uses K3s instead of K3d
# for faster iteration and production-like testing on local systems
#
# SECURITY NOTE: This script uses "privileged" Pod Security Standard for the ESS namespace
# to avoid security context issues during testing (socketpair syscalls, writable dirs).
# In production, use proper Pod Security Admission policies, AppArmor, or SELinux profiles.

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
CONFIG_DIR="$REPO_ROOT/.github/workflows/config"

# Default configuration
HAULER_VERSION="${HAULER_VERSION:-1.3.0}"
K3S_VERSION="${K3S_VERSION:-v1.33.5+k3s1}"
HELM_VERSION="${HELM_VERSION:-v3.19.0}"
ESS_CHART_VERSION="${ESS_CHART_VERSION:-25.11.0}"
DOMAIN="${DOMAIN:-ess.local}"
PLATFORM="${PLATFORM:-$(uname -m)}"

# Directories
WORK_DIR="/tmp/airgap-test"
LOG_DIR="$WORK_DIR/logs"
HAULER_DIR="/opt/hauler"

# Service ports
K3S_REGISTRY_PORT=5001
ESS_REGISTRY_PORT=5002
K3S_FILESERVER_PORT=8080
HELM_FILESERVER_PORT=8081

# Architecture detection
case "$PLATFORM" in
  x86_64|amd64)
    ARCH="amd64"
    ;;
  aarch64|arm64)
    ARCH="arm64"
    ;;
  *)
    echo -e "${RED}❌ Unsupported architecture: $PLATFORM${NC}"
    exit 1
    ;;
esac

# Print functions
print_header() {
  echo -e "\n${BLUE}=================================================${NC}"
  echo -e "${BLUE}$1${NC}"
  echo -e "${BLUE}=================================================${NC}\n"
}

print_step() {
  echo -e "${GREEN}▶ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

# Check if running as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root or with sudo"
    exit 1
  fi
}

# Check prerequisites
check_prerequisites() {
  print_header "Checking Prerequisites"
  
  local missing_deps=()
  
  # Check for required commands
  for cmd in curl tar gzip jq; do
    if ! command -v "$cmd" &> /dev/null; then
      missing_deps+=("$cmd")
    fi
  done
  
  if [ ${#missing_deps[@]} -ne 0 ]; then
    print_error "Missing required dependencies: ${missing_deps[*]}"
    print_step "Install with: apt-get install -y ${missing_deps[*]} (Ubuntu/Debian)"
    print_step "Or: yum install -y ${missing_deps[*]} (RHEL/CentOS)"
    exit 1
  fi
  
  print_success "All prerequisites satisfied"
}

# Setup directories
setup_directories() {
  print_header "Setting Up Directories"
  
  mkdir -p "$WORK_DIR"
  mkdir -p "$LOG_DIR"
  mkdir -p "$HAULER_DIR/k3s"
  mkdir -p "$HAULER_DIR/ess-helm"
  mkdir -p "$HAULER_DIR/helm"
  
  print_success "Directories created"
}

# Install Hauler
install_hauler() {
  print_header "Installing Hauler"
  
  if command -v hauler &> /dev/null; then
    local current_version
    current_version=$(hauler version | grep -oP 'Version:\s+\K[0-9.]+' || echo "unknown")
    if [ "$current_version" = "$HAULER_VERSION" ]; then
      print_success "Hauler v$HAULER_VERSION already installed"
      return
    else
      print_step "Upgrading Hauler from v$current_version to v$HAULER_VERSION"
    fi
  fi
  
  print_step "Downloading Hauler v$HAULER_VERSION for linux/$ARCH..."
  curl -sfL https://get.hauler.dev | bash
  
  if hauler version; then
    print_success "Hauler installed successfully"
  else
    print_error "Failed to install Hauler"
    exit 1
  fi
}

# Phase 1: Build Airgap Assets
build_airgap_assets() {
  print_header "PHASE 1: Building Airgap Assets (Connected)"
  
  cd "$REPO_ROOT" || exit 1
  
  # Build K3s store
  if [ -d "$REPO_ROOT/hauler/k3s/k3s-store" ]; then
    print_warning "K3s store already exists, skipping sync..."
    print_step "Using existing K3s store contents:"
    cd "$REPO_ROOT/hauler/k3s" || exit 1
    hauler store info --store k3s-store | tee "$LOG_DIR/k3s-store-info.log"
  else
    print_step "Building K3s Hauler store..."
    cd "$REPO_ROOT/hauler/k3s" || exit 1
    hauler store sync \
      --store k3s-store \
      --platform "linux/$ARCH" \
      --filename rancher-airgap-k3s.yaml 2>&1 | tee "$LOG_DIR/k3s-sync.log"
    
    print_step "K3s store contents:"
    hauler store info --store k3s-store | tee "$LOG_DIR/k3s-store-info.log"
  fi
  
  # Build ESS store
  if [ -d "$REPO_ROOT/hauler/ess-helm/ess-store" ]; then
    print_warning "ESS store already exists, skipping sync..."
    print_step "Using existing ESS store contents:"
    cd "$REPO_ROOT/hauler/ess-helm" || exit 1
    hauler store info --store ess-store | tee "$LOG_DIR/ess-store-info.log"
  else
    print_step "Building ESS Hauler store..."
    cd "$REPO_ROOT/hauler/ess-helm" || exit 1
    hauler store sync \
      --store ess-store \
      --platform "linux/$ARCH" \
      --filename rancher-airgap-ess-helm.yaml 2>&1 | tee "$LOG_DIR/ess-sync.log"
    
    print_step "ESS store contents:"
    hauler store info --store ess-store | tee "$LOG_DIR/ess-store-info.log"
  fi
  
  # Build Helm store
  if [ -d "$REPO_ROOT/hauler/helm/helm-store" ]; then
    print_warning "Helm store already exists, skipping sync..."
    print_step "Using existing Helm store contents:"
    cd "$REPO_ROOT/hauler/helm" || exit 1
    hauler store info --store helm-store | tee "$LOG_DIR/helm-store-info.log"
  else
    print_step "Building Helm Hauler store..."
    cd "$REPO_ROOT/hauler/helm" || exit 1
    hauler store sync \
      --store helm-store \
      --filename rancher-airgap-helm.yaml 2>&1 | tee "$LOG_DIR/helm-sync.log"
    
    print_step "Helm store contents:"
    hauler store info --store helm-store | tee "$LOG_DIR/helm-store-info.log"
  fi
  
  print_success "Airgap assets ready"
}

# Phase 2: Install K3s
install_k3s() {
  print_header "PHASE 2: Installing K3s"
  
  # Check if K3s is already running
  if systemctl is-active --quiet k3s 2>/dev/null; then
    print_warning "K3s is already running"
    print_step "Stopping existing K3s installation..."
    systemctl stop k3s
    sleep 5
  fi
  
  # Configure K3s to use local registries from config template
  print_step "Configuring K3s registries..."
  mkdir -p /etc/rancher/k3s
  
  # Copy registry configuration from config directory
  # Substitute port variables if needed
  sed -e "s/localhost:5001/localhost:$K3S_REGISTRY_PORT/g" \
      -e "s/localhost:5002/localhost:$ESS_REGISTRY_PORT/g" \
      "$CONFIG_DIR/k3s-registries.yaml" > /etc/rancher/k3s/registries.yaml
  
  print_step "Downloading K3s from local fileserver..."
  cd "$REPO_ROOT/hauler/k3s" || exit 1
  
  # Start temporary fileserver to get K3s binary (use an isolated writable directory)
  print_step "Starting temporary fileserver for K3s installation..."
  mkdir -p "$WORK_DIR/k3s-fileserver"
  nohup hauler store serve fileserver --port $K3S_FILESERVER_PORT --store k3s-store --directory "$WORK_DIR/k3s-fileserver" > "$LOG_DIR/temp-fileserver.log" 2>&1 &
  local temp_fileserver_pid=$!
  
  # Wait for fileserver to be reachable
  local retries=0
  while [ $retries -lt 15 ]; do
    if curl -sSf "http://localhost:$K3S_FILESERVER_PORT/" > /dev/null 2>&1; then
      break
    fi
    retries=$((retries + 1))
    sleep 1
  done
  
  if [ $retries -eq 15 ]; then
    print_error "Temporary K3s fileserver failed to start"
    print_step "Temp fileserver log (last 50 lines):"
    tail -n 50 "$LOG_DIR/temp-fileserver.log" || true
    kill $temp_fileserver_pid 2>/dev/null || true
    exit 1
  fi
  
  # Determine correct K3s binary name by arch
  local K3S_SRC_BIN="k3s"
  if [ "$ARCH" = "arm64" ]; then
    K3S_SRC_BIN="k3s-arm64"
  fi
  
  # Download K3s binary with fallback to repo files if fileserver path differs
  print_step "Downloading K3s binary ($K3S_SRC_BIN)..."
  if curl -sfL "http://localhost:$K3S_FILESERVER_PORT/$K3S_SRC_BIN" -o /usr/local/bin/k3s; then
    chmod +x /usr/local/bin/k3s
  else
    print_warning "Failed to get $K3S_SRC_BIN from temp fileserver, trying repository fallback..."
    if [ -f "$REPO_ROOT/hauler/k3s/fileserver/$K3S_SRC_BIN" ]; then
      cp "$REPO_ROOT/hauler/k3s/fileserver/$K3S_SRC_BIN" /usr/local/bin/k3s
      chmod +x /usr/local/bin/k3s
    else
      print_error "K3s binary not found at fileserver or repo fallback"
      print_step "Fileserver index:"
      curl -sf "http://localhost:$K3S_FILESERVER_PORT/" || true
      kill $temp_fileserver_pid 2>/dev/null || true
      exit 1
    fi
  fi
  
  # Download K3s install script with fallback
  print_step "Downloading K3s install script..."
  if curl -sfL "http://localhost:$K3S_FILESERVER_PORT/install.sh" -o /tmp/k3s-install.sh; then
    chmod +x /tmp/k3s-install.sh
  elif [ -f "$REPO_ROOT/hauler/k3s/fileserver/install.sh" ]; then
    print_warning "Failed to get install.sh from fileserver, using repository fallback"
    cp "$REPO_ROOT/hauler/k3s/fileserver/install.sh" /tmp/k3s-install.sh
    chmod +x /tmp/k3s-install.sh
  else
    print_error "K3s install.sh not found at fileserver or repo fallback"
    print_step "Fileserver index:"
    curl -sf "http://localhost:$K3S_FILESERVER_PORT/" || true
    kill $temp_fileserver_pid 2>/dev/null || true
    exit 1
  fi
  
  # Kill temporary fileserver
  kill $temp_fileserver_pid || true
  sleep 2
  
  # Install K3s
  print_step "Installing K3s $K3S_VERSION..."
  INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_VERSION="$K3S_VERSION" \
  K3S_TOKEN="airgap-test-token" \
    /tmp/k3s-install.sh --disable=traefik
  
  # Wait for K3s to be ready
  print_step "Waiting for K3s to be ready..."
  local retries=0
  while [ $retries -lt 60 ]; do
    if k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; then
      print_success "K3s is ready"
      break
    fi
    retries=$((retries + 1))
    sleep 2
  done
  
  if [ $retries -eq 60 ]; then
    print_error "K3s failed to become ready"
    exit 1
  fi
  
  # Setup kubectl alias
  export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
  ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl || true
  
  print_step "K3s cluster info:"
  k3s kubectl cluster-info
  k3s kubectl get nodes
  
  print_success "K3s installed successfully"
}

# Phase 3: Start Hauler Services
start_hauler_services() {
  print_header "PHASE 3: Starting Hauler Registry and Fileserver"
  
  # Source shared functions
  source "$SCRIPT_DIR/hauler-functions.sh"
  
  # Stop any existing Hauler services
  stop_hauler_services
  
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
  
  # Start K3s fileserver
  start_hauler_fileserver \
    "$K3S_FILESERVER_PORT" \
    "k3s-store" \
    "$REPO_ROOT/hauler/k3s" \
    "$LOG_DIR/k3s-fileserver.log" \
    "$WORK_DIR/fileserver.pid" \
    "$WORK_DIR/k3s-fileserver" || exit 1
  
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
  
  # Wait for K3s to be ready again
  local retries=0
  while [ $retries -lt 30 ]; do
    if k3s kubectl get nodes 2>/dev/null | grep -q "Ready"; then
      print_success "K3s restarted and ready"
      break
    fi
    retries=$((retries + 1))
    sleep 2
  done
  
  print_success "All Hauler services started successfully"
}

# Phase 4: Install Helm and Deploy ESS
deploy_ess() {
  print_header "PHASE 4: Deploying ESS from Local Sources"
  
  # Install Helm from local fileserver
  print_step "Installing Helm from local fileserver..."
  if ! curl -sfL "http://localhost:$HELM_FILESERVER_PORT/helm-linux-${ARCH}.tar.gz" -o /tmp/helm.tar.gz; then
    print_error "Failed to download Helm from fileserver"
    print_step "Checking fileserver contents:"
    curl -f "http://localhost:$HELM_FILESERVER_PORT/" || true
    exit 1
  fi
  
  tar -xzf /tmp/helm.tar.gz -C /tmp
  mv "/tmp/linux-${ARCH}/helm" /usr/local/bin/helm
  chmod +x /usr/local/bin/helm
  
  print_step "Helm version:"
  helm version
  
  # Create ESS namespace with privileged Pod Security Standard for testing
  print_step "Creating ESS namespace with privileged security for testing..."
  k3s kubectl create namespace ess --dry-run=client -o yaml | k3s kubectl apply -f -
  k3s kubectl label namespace ess \
    pod-security.kubernetes.io/enforce=privileged \
    pod-security.kubernetes.io/audit=privileged \
    pod-security.kubernetes.io/warn=privileged \
    --overwrite
  
  print_warning "NOTE: Privileged Pod Security is for TESTING ONLY - not for production!"
  
  # Create TLS certificate
  print_step "Creating TLS certificate..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/tls.key -out /tmp/tls.crt \
    -subj "/CN=*.${DOMAIN}" \
    -addext "subjectAltName=DNS:${DOMAIN},DNS:*.${DOMAIN}" 2>/dev/null
  
  k3s kubectl create secret tls ess-wildcard-tls -n ess \
    --cert=/tmp/tls.crt --key=/tmp/tls.key \
    --dry-run=client -o yaml | k3s kubectl apply -f -
  
  # Prepare ESS values file with variable substitution
  print_step "Preparing ESS Helm values..."
  sed "s/ess\.local/${DOMAIN}/g" "$CONFIG_DIR/ess-values.yaml" > /tmp/ess-values.yaml
  
  # Validate ESS values against chart schema
  print_step "Validating ESS values against Helm chart schema..."
  if ! helm lint \
    "oci://localhost:$ESS_REGISTRY_PORT/hauler/matrix-stack" \
    --version "$ESS_CHART_VERSION" \
    --values /tmp/ess-values.yaml \
    --plain-http 2>&1 | tee "$LOG_DIR/helm-lint.log"; then
    print_warning "Helm lint found issues (see $LOG_DIR/helm-lint.log)"
    print_step "Continuing deployment anyway..."
  else
    print_success "ESS values validated successfully"
  fi
  
  # Install ESS chart from local registry
  print_step "Installing ESS from local Hauler registry..."
  cd "$REPO_ROOT/hauler/ess-helm" || exit 1
  
  # Install directly from the local OCI registry using plain HTTP
  helm upgrade --install ess \
    "oci://localhost:$ESS_REGISTRY_PORT/hauler/matrix-stack" \
    --version "$ESS_CHART_VERSION" \
    --namespace ess \
    -f /tmp/ess-values.yaml \
    --timeout 10m \
    --plain-http \
    --wait 2>&1 | tee "$LOG_DIR/ess-install.log" || {
      print_error "Failed to install ESS from registry, trying chart extraction..."
      
      # Fallback: Helm pull the chart from OCI then install from tgz
      print_step "Pulling chart tarball via Helm..."
      mkdir -p /tmp/charts
      if helm pull "oci://localhost:$ESS_REGISTRY_PORT/hauler/matrix-stack" --version "$ESS_CHART_VERSION" --plain-http -d /tmp/charts; then
        print_step "Installing ESS from pulled chart..."
        helm upgrade --install ess \
          "/tmp/charts/matrix-stack-${ESS_CHART_VERSION}.tgz" \
          --namespace ess \
          -f /tmp/ess-values.yaml \
          --timeout 10m \
          --wait 2>&1 | tee -a "$LOG_DIR/ess-install.log"
      else
        print_error "Helm pull of chart failed"
      fi
    }
  
  print_success "ESS deployment initiated"
}

# Phase 5: Validation
validate_deployment() {
  print_header "PHASE 5: Validation and Verification"
  
  # Wait for pods
  print_step "Waiting for ESS pods to be ready (this may take several minutes)..."
  k3s kubectl wait --for=condition=ready pod \
    --all \
    -n ess \
    --timeout=600s || {
    print_warning "Some pods may not be ready yet"
    k3s kubectl get pods -n ess
  }
  
  # Show pod status
  print_step "ESS pod status:"
  k3s kubectl get pods -n ess -o wide
  
  # Verify image sources
  print_step "Verifying all images are from local sources..."
  if [ -f "$SCRIPT_DIR/verify-images.sh" ]; then
    bash "$SCRIPT_DIR/verify-images.sh" ess || print_warning "Image verification had warnings"
  else
    print_warning "Image verification script not found, skipping..."
  fi
  
  # Check deployments
  print_step "ESS deployments:"
  k3s kubectl get deployments -n ess
  
  # Check services
  print_step "ESS services:"
  k3s kubectl get services -n ess
  
  # Summary
  print_header "Test Summary"
  
  local total_pods
  local ready_pods
  total_pods=$(k3s kubectl get pods -n ess --no-headers | wc -l)
  ready_pods=$(k3s kubectl get pods -n ess --no-headers | grep -c "Running" || echo "0")
  
  echo "Domain: $DOMAIN"
  echo "K3s Version: $K3S_VERSION"
  echo "ESS Chart Version: $ESS_CHART_VERSION"
  echo "Platform: linux/$ARCH"
  echo "Total Pods: $total_pods"
  echo "Running Pods: $ready_pods"
  echo ""
  
  if [ "$ready_pods" -eq "$total_pods" ] && [ "$total_pods" -gt 0 ]; then
    print_success "AIRGAP TEST PASSED - All pods are running"
    echo ""
    print_step "Access your ESS deployment:"
    echo "  1. Add DNS entries or update /etc/hosts:"
    echo "     127.0.0.1 $DOMAIN matrix.$DOMAIN account.$DOMAIN chat.$DOMAIN admin.$DOMAIN mrtc.$DOMAIN"
    echo "  2. Get service NodePorts: k3s kubectl get svc -n ess"
    echo "  3. Access Element Web at http://chat.$DOMAIN:<NodePort>"
    return 0
  else
    print_warning "AIRGAP TEST COMPLETED WITH WARNINGS"
    echo ""
    print_step "Debug failed pods with:"
    echo "  k3s kubectl describe pods -n ess"
    echo "  k3s kubectl logs -n ess <pod-name>"
    return 1
  fi
}

# Light cleanup function - preserves Hauler stores
light_cleanup() {
  print_header "Light Cleanup (Preserving Hauler Stores)"
  
  print_step "Stopping Hauler services..."
  if [ -f "$WORK_DIR/k3s-registry.pid" ]; then
    kill "$(cat "$WORK_DIR/k3s-registry.pid")" 2>/dev/null || true
  fi
  if [ -f "$WORK_DIR/ess-registry.pid" ]; then
    kill "$(cat "$WORK_DIR/ess-registry.pid")" 2>/dev/null || true
  fi
  if [ -f "$WORK_DIR/fileserver.pid" ]; then
    kill "$(cat "$WORK_DIR/fileserver.pid")" 2>/dev/null || true
  fi
  if [ -f "$WORK_DIR/helm-fileserver.pid" ]; then
    kill "$(cat "$WORK_DIR/helm-fileserver.pid")" 2>/dev/null || true
  fi
  
  pkill -f "hauler store serve" || true
  
  print_step "Uninstalling K3s..."
  if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    /usr/local/bin/k3s-uninstall.sh
  fi
  
  print_step "Removing temporary files (keeping Hauler stores)..."
  rm -f "$WORK_DIR"/*.pid
  rm -f "$WORK_DIR"/*.log
  rm -rf "$LOG_DIR"
  
  print_success "Light cleanup completed - Hauler stores preserved in $REPO_ROOT/hauler"
  print_step "Next run will skip Hauler sync and use existing stores"
}

# Full cleanup function
cleanup() {
  print_header "Full Cleanup"
  
  read -p "Do you want to remove K3s and all test data including Hauler stores? (y/N): " -n 1 -r
  echo
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_step "Cleanup cancelled"
    return
  fi
  
  # Source shared functions for cleanup
  source "$SCRIPT_DIR/hauler-functions.sh" 2>/dev/null || true
  
  print_step "Stopping Hauler services..."
  if [ -f "$WORK_DIR/k3s-registry.pid" ]; then
    kill "$(cat "$WORK_DIR/k3s-registry.pid")" 2>/dev/null || true
  fi
  if [ -f "$WORK_DIR/ess-registry.pid" ]; then
    kill "$(cat "$WORK_DIR/ess-registry.pid")" 2>/dev/null || true
  fi
  if [ -f "$WORK_DIR/fileserver.pid" ]; then
    kill "$(cat "$WORK_DIR/fileserver.pid")" 2>/dev/null || true
  fi
  if [ -f "$WORK_DIR/helm-fileserver.pid" ]; then
    kill "$(cat "$WORK_DIR/helm-fileserver.pid")" 2>/dev/null || true
  fi
  
  # Use shared function if available
  if type stop_hauler_services &>/dev/null; then
    stop_hauler_services
  else
    pkill -f "hauler store serve" || true
    sleep 2
  fi
  
  print_step "Uninstalling K3s..."
  if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    /usr/local/bin/k3s-uninstall.sh
  fi
  
  print_step "Removing work directory..."
  rm -rf "$WORK_DIR"
  
  print_step "Removing Hauler stores..."
  rm -rf "$REPO_ROOT/hauler/k3s/k3s-store"
  rm -rf "$REPO_ROOT/hauler/ess-helm/ess-store"
  rm -rf "$REPO_ROOT/hauler/helm/helm-store"
  
  print_success "Full cleanup completed"
}

# Main function
main() {
  print_header "Local Airgap Test for K3s + ESS"
  
  echo "Configuration:"
  echo "  Hauler Version: $HAULER_VERSION"
  echo "  K3s Version: $K3S_VERSION"
  echo "  ESS Chart Version: $ESS_CHART_VERSION"
  echo "  Domain: $DOMAIN"
  echo "  Platform: linux/$ARCH"
  echo ""
  
  # Parse arguments
  case "${1:-run}" in
    run|test)
      check_root
      check_prerequisites
      setup_directories
      install_hauler
      build_airgap_assets
      install_k3s
      start_hauler_services
      deploy_ess
      validate_deployment
      ;;
    light-cleanup|reset)
      check_root
      light_cleanup
      ;;
    cleanup|clean|full-cleanup)
      check_root
      cleanup
      ;;
    help|--help|-h)
      echo "Usage: $0 [command]"
      echo ""
      echo "Commands:"
      echo "  run            Run the complete airgap test (default)"
      echo "  light-cleanup  Reset K3s and ESS but keep Hauler stores (fast iteration)"
      echo "  reset          Alias for light-cleanup"
      echo "  cleanup        Full cleanup: remove everything including Hauler stores"
      echo "  clean          Alias for cleanup"
      echo "  help           Show this help message"
      echo ""
      echo "Environment Variables:"
      echo "  DOMAIN              Domain for ESS (default: ess.local)"
      echo "  K3S_VERSION         K3s version (default: $K3S_VERSION)"
      echo "  ESS_CHART_VERSION   ESS chart version (default: $ESS_CHART_VERSION)"
      echo "  HAULER_VERSION      Hauler version (default: $HAULER_VERSION)"
      exit 0
      ;;
    *)
      print_error "Unknown command: $1"
      echo "Run '$0 help' for usage information"
      exit 1
      ;;
  esac
}

# Run main function
main "$@"
