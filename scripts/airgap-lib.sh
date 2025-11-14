#!/bin/bash
# Airgap Function Library
# Shared functions for building and deploying airgap environments with K3s + ESS
#
# This library can be sourced by:
# - local-airgap-test.sh (end-to-end testing)
# - build-airgap-assets.sh (create Hauler stores only)
# - deploy-airgap.sh (deploy from existing Hauler stores)
# - GitHub Actions workflows

# Prevent multiple sourcing
if [ -n "${AIRGAP_LIB_LOADED:-}" ]; then
  return 0
fi
AIRGAP_LIB_LOADED=1

# ============================================================================
# Color codes for output
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================================
# Print functions
# ============================================================================
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

# ============================================================================
# Environment detection and validation
# ============================================================================

# Detect architecture
detect_architecture() {
  local platform="${1:-$(uname -m)}"
  
  case "$platform" in
    x86_64|amd64)
      echo "amd64"
      ;;
    aarch64|arm64)
      echo "arm64"
      ;;
    *)
      print_error "Unsupported architecture: $platform"
      return 1
      ;;
  esac
}

# Check if running as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    print_error "This operation must be run as root or with sudo"
    return 1
  fi
  return 0
}

# Check prerequisites
check_prerequisites() {
  local mode="${1:-full}"  # full, build-only, deploy-only
  
  print_header "Checking Prerequisites"
  
  local missing_deps=()
  
  # Base requirements
  for cmd in curl tar gzip jq; do
    if ! command -v "$cmd" &> /dev/null; then
      missing_deps+=("$cmd")
    fi
  done
  
  # Additional requirements for deployment
  if [ "$mode" != "build-only" ]; then
    for cmd in openssl; do
      if ! command -v "$cmd" &> /dev/null; then
        missing_deps+=("$cmd")
      fi
    done
  fi
  
  if [ ${#missing_deps[@]} -ne 0 ]; then
    print_error "Missing required dependencies: ${missing_deps[*]}"
    print_step "Install with: apt-get install -y ${missing_deps[*]} (Ubuntu/Debian)"
    print_step "Or: yum install -y ${missing_deps[*]} (RHEL/CentOS)"
    return 1
  fi
  
  print_success "All prerequisites satisfied"
  return 0
}

# ============================================================================
# Directory management
# ============================================================================

setup_directories() {
  local work_dir="${1:-/tmp/airgap}"
  local log_dir="${2:-$work_dir/logs}"
  
  print_header "Setting Up Directories"
  
  mkdir -p "$work_dir"
  mkdir -p "$log_dir"
  
  print_success "Directories created: $work_dir, $log_dir"
}

# ============================================================================
# Hauler installation
# ============================================================================

install_hauler() {
  local expected_version="${1:-1.3.1}"
  local arch="${2:-amd64}"
  
  print_header "Installing Hauler"
  
  if command -v hauler &> /dev/null; then
    local current_version
    current_version=$(hauler version 2>&1 | grep -oP 'GitVersion:\s+v?\K[0-9.]+' || echo "unknown")
    
    # Accept any 1.x version as compatible since we can't pin the install script
    if [[ "$current_version" =~ ^1\. ]]; then
      print_success "Hauler v$current_version already installed - skipping download"
      print_step "Expected version: v$expected_version (auto-updated by Renovate)"
      return 0
    elif [ "$current_version" != "unknown" ]; then
      print_warning "Hauler v$current_version found (expected v$expected_version)"
      print_step "Installing Hauler (latest version from install script)..."
    else
      print_warning "Unable to determine Hauler version, reinstalling..."
    fi
  else
    print_step "Hauler not found - installing from https://get.hauler.dev..."
  fi
  
  print_step "Downloading Hauler for linux/$arch..."
  curl -sfL https://get.hauler.dev | bash
  
  if hauler version; then
    local installed_version
    installed_version=$(hauler version 2>&1 | grep -oP 'GitVersion:\s+v?\K[0-9.]+' || echo "unknown")
    print_success "Hauler v$installed_version installed successfully"
    if [ "$installed_version" != "$expected_version" ]; then
      print_warning "Installed v$installed_version differs from expected v$expected_version"
      print_step "This is expected - the install script always installs the latest version"
    fi
    return 0
  else
    print_error "Failed to install Hauler"
    return 1
  fi
}

# ============================================================================
# Hauler store building
# ============================================================================

build_hauler_store() {
  local store_name="$1"
  local store_dir="$2"
  local manifest_file="$3"
  local platform="${4:-linux/amd64}"
  local log_file="${5:-/dev/null}"
  
  if [ -d "$store_dir/$store_name" ]; then
    print_warning "$store_name store already exists, skipping sync..."
    print_step "Using existing $store_name store contents:"
    cd "$store_dir" || return 1
    hauler store info --store "$store_name" | tee -a "$log_file"
    return 0
  else
    print_step "Building $store_name Hauler store..."
    cd "$store_dir" || return 1
    hauler store sync \
      --store "$store_name" \
      --platform "$platform" \
      --filename "$manifest_file" 2>&1 | tee -a "$log_file"
    
    print_step "$store_name store contents:"
    hauler store info --store "$store_name" | tee -a "$log_file"
    return 0
  fi
}

build_all_hauler_stores() {
  local repo_root="$1"
  local arch="${2:-amd64}"
  local log_dir="${3:-/tmp/airgap/logs}"
  local build_dir="$repo_root/hauler"

  print_header "PHASE: Building Airgap Assets (Connected)"

  # Build K3s store
  build_hauler_store \
    "k3s-store" \
    "$build_dir/k3s" \
    "rancher-airgap-k3s.yaml" \
    "linux/$arch" \
    "$log_dir/k3s-sync.log" || return 1

  # Build ESS store
  build_hauler_store \
    "ess-store" \
    "$build_dir/ess-helm" \
    "rancher-airgap-ess-helm.yaml" \
    "linux/$arch" \
    "$log_dir/ess-sync.log" || return 1

  # Build Helm store (no platform needed)
  build_hauler_store \
    "helm-store" \
    "$build_dir/helm" \
    "rancher-airgap-helm.yaml" \
    "" \
    "$log_dir/helm-sync.log" || return 1
  
  print_success "Airgap assets ready"
  return 0
}

# ============================================================================
# K3s installation
# ============================================================================

setup_k3s_kubeconfig() {
  print_step "Setting up kubectl access..."
  
  # Setup for root
  mkdir -p /root/.kube
  k3s kubectl config view --raw > /root/.kube/config
  chmod 600 /root/.kube/config
  
  # Setup for the user who invoked sudo (if not root)
  if [ -n "${SUDO_USER:-}" ] && [ "$SUDO_USER" != "root" ]; then
    local user_home
    user_home=$(eval echo "~$SUDO_USER")
    
    print_step "Setting up kubectl access for user: $SUDO_USER"
    sudo -u "$SUDO_USER" mkdir -p "$user_home/.kube"
    k3s kubectl config view --raw > "$user_home/.kube/config"
    chown "$SUDO_USER:$SUDO_USER" "$user_home/.kube/config"
    chmod 600 "$user_home/.kube/config"
  fi
  
  # Create kubectl symlink
  ln -sf /usr/local/bin/k3s /usr/local/bin/kubectl || true
  
  # Set KUBECONFIG for this session
  export KUBECONFIG=/root/.kube/config
  
  print_success "kubectl configured for root${SUDO_USER:+ and $SUDO_USER}"
}

configure_k3s_registries() {
  local config_file="$1"
  local k3s_registry_port="${2:-5001}"
  local ess_registry_port="${3:-5002}"
  
  print_step "Configuring K3s registries..."
  mkdir -p /etc/rancher/k3s
  
  sed -e "s/localhost:5001/localhost:$k3s_registry_port/g" \
      -e "s/localhost:5002/localhost:$ess_registry_port/g" \
      "$config_file" > /etc/rancher/k3s/registries.yaml
  
  print_success "K3s registry configuration updated"
}

install_k3s_from_hauler() {
  local repo_root="$1"
  local k3s_version="$2"
  local arch="${3:-amd64}"
  local work_dir="${4:-/tmp/airgap}"
  local log_dir="${5:-$work_dir/logs}"
  local fileserver_port="${6:-8080}"
  
  print_header "PHASE: Installing K3s"
  
  # Check if K3s is already installed and running
  if systemctl is-active --quiet k3s 2>/dev/null && command -v k3s &>/dev/null; then
    print_success "K3s is already running"
    setup_k3s_kubeconfig
    
    print_step "K3s cluster info:"
    kubectl cluster-info
    kubectl get nodes
    
    return 0
  fi
  
  print_step "K3s not found - performing fresh installation..."
  
  cd "$REPO_ROOT/hauler/k3s" || return 1
  
  # Start temporary fileserver to get K3s binary
  print_step "Starting temporary fileserver for K3s installation..."
  mkdir -p "$work_dir/k3s-fileserver"
  nohup hauler store serve fileserver --port "$fileserver_port" --store k3s-store --directory "$work_dir/k3s-fileserver" > "$log_dir/temp-fileserver.log" 2>&1 &
  local temp_fileserver_pid=$!
  
  # Wait for fileserver to be reachable
  local retries=0
  while [ $retries -lt 15 ]; do
    if curl -sSf "http://localhost:$fileserver_port/" > /dev/null 2>&1; then
      break
    fi
    retries=$((retries + 1))
    sleep 1
  done
  
  if [ $retries -eq 15 ]; then
    print_error "Temporary K3s fileserver failed to start"
    kill $temp_fileserver_pid 2>/dev/null || true
    return 1
  fi
  
  # Determine correct K3s binary name by arch
  local k3s_src_bin="k3s"
  if [ "$arch" = "arm64" ]; then
    k3s_src_bin="k3s-arm64"
  fi
  
  # Download K3s binary
  print_step "Downloading K3s binary ($k3s_src_bin)..."
  if ! curl -sfL "http://localhost:$fileserver_port/$k3s_src_bin" -o /usr/local/bin/k3s; then
    print_error "Failed to download K3s binary"
    kill $temp_fileserver_pid 2>/dev/null || true
    return 1
  fi
  chmod +x /usr/local/bin/k3s
  
  # Download K3s install script
  print_step "Downloading K3s install script..."
  if ! curl -sfL "http://localhost:$fileserver_port/install.sh" -o /tmp/k3s-install.sh; then
    print_error "Failed to download K3s install script"
    kill $temp_fileserver_pid 2>/dev/null || true
    return 1
  fi
  chmod +x /tmp/k3s-install.sh
  
  # Kill temporary fileserver
  kill $temp_fileserver_pid || true
  sleep 2
  
  # Install K3s
  print_step "Installing K3s $k3s_version..."
  INSTALL_K3S_SKIP_DOWNLOAD=true \
  INSTALL_K3S_VERSION="$k3s_version" \
  K3S_TOKEN="airgap-token" \
    /tmp/k3s-install.sh --disable=traefik
  
  # Wait for K3s to be ready
  print_step "Waiting for K3s to be ready..."
  local retries=0
  while [ $retries -lt 60 ]; do
    if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
      print_success "K3s is ready"
      break
    fi
    retries=$((retries + 1))
    sleep 2
  done
  
  if [ $retries -eq 60 ]; then
    print_error "K3s failed to become ready"
    return 1
  fi
  
  # Setup kubeconfig
  setup_k3s_kubeconfig
  
  print_step "K3s cluster info:"
  kubectl cluster-info
  kubectl get nodes
  
  print_success "K3s installed successfully"
  return 0
}

# ============================================================================
# Helm installation
# ============================================================================

install_helm_from_hauler() {
  local helm_version="$1"
  local arch="${2:-amd64}"
  local fileserver_port="${3:-8081}"
  
  print_step "Installing Helm from local fileserver..."
  
  # Check if Helm is already installed
  if command -v helm &> /dev/null; then
    local current_helm_version
    current_helm_version=$(helm version --template='{{.Version}}' 2>/dev/null || echo "unknown")
    if [[ "$current_helm_version" == "$helm_version" ]]; then
      print_success "Helm $helm_version already installed - skipping download"
      return 0
    else
      print_step "Helm $current_helm_version found, upgrading to $helm_version..."
    fi
  fi
  
  if ! curl -sfL "http://localhost:$fileserver_port/helm-linux-${arch}.tar.gz" -o /tmp/helm.tar.gz; then
    print_error "Failed to download Helm from fileserver"
    return 1
  fi
  
  tar -xzf /tmp/helm.tar.gz -C /tmp
  mv "/tmp/linux-${arch}/helm" /usr/local/bin/helm
  chmod +x /usr/local/bin/helm
  
  print_step "Helm version:"
  helm version
  
  print_success "Helm installed successfully"
  return 0
}

# ============================================================================
# ESS deployment
# ============================================================================

deploy_ess() {
  local domain="$1"
  local ess_chart_version="$2"
  local ess_registry_port="${3:-5002}"
  local config_dir="$4"
  local log_dir="${5:-/tmp/airgap/logs}"
  local repo_root="${6:-$(pwd)}"
  
  print_header "PHASE: Deploying ESS from Local Sources"
  
  print_step "Creating ESS namespace"
  kubectl create namespace ess
  
  
  # Create TLS certificate
  print_step "Creating TLS certificate..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /tmp/tls.key -out /tmp/tls.crt \
    -subj "/CN=*.${domain}" \
    -addext "subjectAltName=DNS:${domain},DNS:*.${domain}" 2>/dev/null
  
  kubectl create secret tls ess-wildcard-tls -n ess \
    --cert=/tmp/tls.crt --key=/tmp/tls.key \
    --dry-run=client -o yaml | kubectl apply -f -
  
  # Prepare ESS values file with variable substitution
  print_step "Preparing ESS Helm values..."
  sed "s/ess\.local/${domain}/g" "$config_dir/ess-values.yaml" > /tmp/ess-values.yaml
  
  # Install ESS chart from local registry
  print_step "Installing ESS from local Hauler registry..."
  cd "$REPO_ROOT/hauler/ess-helm" || return 1
  
  # Install directly from the local OCI registry using plain HTTP
  if helm upgrade --install ess \
    "oci://localhost:$ess_registry_port/hauler/matrix-stack" \
    --version "$ess_chart_version" \
    --namespace ess \
    -f /tmp/ess-values.yaml \
    --timeout 10m \
    --plain-http \
    --wait 2>&1 | tee "$log_dir/ess-install.log"; then
    print_success "ESS deployment completed"
    return 0
  else
    print_error "Failed to install ESS from registry, trying chart extraction..."
    
    # Fallback: Helm pull the chart from OCI then install from tgz
    mkdir -p /tmp/charts
    if helm pull "oci://localhost:$ess_registry_port/hauler/matrix-stack" --version "$ess_chart_version" --plain-http -d /tmp/charts; then
      print_step "Installing ESS from pulled chart..."
      helm upgrade --install ess \
        "/tmp/charts/matrix-stack-${ess_chart_version}.tgz" \
        --namespace ess \
        -f /tmp/ess-values.yaml \
        --timeout 10m \
        --wait 2>&1 | tee -a "$log_dir/ess-install.log"
      print_success "ESS deployment completed"
      return 0
    else
      print_error "Helm pull of chart failed"
      return 1
    fi
  fi
}

# ============================================================================
# Validation
# ============================================================================

validate_ess_deployment() {
  local domain="$1"
  local k3s_version="$2"
  local ess_chart_version="$3"
  local arch="$4"
  
  print_header "PHASE: Validation and Verification"
  
  # Wait for main application pods (exclude Jobs and completed pods)
  print_step "Waiting for ESS application pods to be ready (this may take several minutes)..."
  print_step "Note: Ignoring completed init/setup jobs"
  
  # Wait specifically for the main Synapse pod and deployments (not jobs)
  if kubectl wait --for=condition=ready pod \
    -l 'app.kubernetes.io/component in (main,synapse-main)' \
    -n ess \
    --timeout=600s 2>/dev/null; then
    print_success "Synapse main pod is ready"
  else
    print_warning "Synapse main pod may not be ready yet"
  fi
  
  # Wait for other deployment pods (not jobs)
  if kubectl wait \
    --for=jsonpath='{.status.readyReplicas}'='1' \
    statefulset/ess-synapse-main \
    -n ess --timeout=300s 2>/dev/null; then
    print_success "All ESS deployment pods are ready"
  else
    print_warning "Some deployment pods may still be starting"
  fi
  
  # Show pod status
  print_step "ESS pod status:"
  kubectl get pods -n ess -o wide
  
  # Check deployments
  print_step "ESS deployments:"
  kubectl get deployments -n ess
  
  # Check services
  print_step "ESS services:"
  kubectl get services -n ess
  
  # Summary
  print_header "Deployment Summary"
  
  local total_pods
  local ready_pods
  local completed_jobs
  local running_deployments
  
  total_pods=$(kubectl get pods -n ess --no-headers | wc -l)
  ready_pods=$(kubectl get pods -n ess --no-headers | grep -c "Running" || echo "0")
  completed_jobs=$(kubectl get pods -n ess --no-headers | grep -c "Completed" || echo "0")
  running_deployments=$(kubectl get deployments,statefulsets -n ess --no-headers 2>/dev/null | wc -l)
  
  echo "Domain: $domain"
  echo "K3s Version: $k3s_version"
  echo "ESS Chart Version: $ess_chart_version"
  echo "Platform: linux/$arch"
  echo "Total Pods: $total_pods (Running: $ready_pods, Completed Jobs: $completed_jobs)"
  echo "Deployments/StatefulSets: $running_deployments"
  echo ""
  
  # Check if all non-job pods are running
  local expected_running=$((total_pods - completed_jobs))
  if [ "$ready_pods" -ge "$expected_running" ] && [ "$ready_pods" -gt 0 ]; then
    print_success "DEPLOYMENT SUCCESSFUL - All application pods are running"
    echo ""
    print_step "Access your ESS deployment:"
    echo "  1. Add DNS entries or update /etc/hosts:"
    echo "     127.0.0.1 $domain matrix.$domain account.$domain chat.$domain admin.$domain mrtc.$domain"
    echo "  2. Get service NodePorts: kubectl get svc -n ess"
    echo "  3. Access Element Web at http://chat.$domain:<NodePort>"
    return 0
  else
    print_warning "DEPLOYMENT COMPLETED WITH WARNINGS"
    echo ""
    print_step "Debug failed pods with:"
    echo "  kubectl describe pods -n ess"
    echo "  kubectl logs -n ess <pod-name>"
    return 1
  fi
}

# ============================================================================
# Export functions for subshells
# ============================================================================

export -f print_header print_step print_warning print_error print_success
export -f detect_architecture check_root check_prerequisites setup_directories
export -f install_hauler build_hauler_store build_all_hauler_stores
export -f setup_k3s_kubeconfig configure_k3s_registries install_k3s_from_hauler
export -f install_helm_from_hauler deploy_ess validate_ess_deployment
