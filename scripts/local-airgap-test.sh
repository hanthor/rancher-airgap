#!/bin/bash
# Local Airgap Test Script for K3s + ESS Deployment
# End-to-end test: builds Hauler stores AND deploys (full cycle)
#
# This script mirrors the GitHub Actions airgap test workflow but uses K3s
# for faster iteration and production-like testing on local systems.
#
# SECURITY NOTE: This script uses "privileged" Pod Security Standard for the ESS namespace
# to avoid security context issues during testing (socketpair syscalls, writable dirs).
# In production, use proper Pod Security Admission policies, AppArmor, or SELinux profiles.

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$REPO_ROOT/.github/workflows/config"

# Source the airgap function library
source "$SCRIPT_DIR/airgap-lib.sh"
source "$SCRIPT_DIR/hauler-functions.sh"

# Default configuration
HAULER_VERSION="${HAULER_VERSION:-1.3.1}"
K3S_VERSION="${K3S_VERSION:-v1.33.5+k3s1}"
HELM_VERSION="${HELM_VERSION:-v3.19.0}"
ESS_CHART_VERSION="${ESS_CHART_VERSION:-25.11.0}"
DOMAIN="${DOMAIN:-ess.local}"
PLATFORM="${PLATFORM:-$(uname -m)}"

# Directories
WORK_DIR="/tmp/airgap-test"
LOG_DIR="$WORK_DIR/logs"

# Service ports
K3S_REGISTRY_PORT=5001
ESS_REGISTRY_PORT=5002
K3S_FILESERVER_PORT=8080
HELM_FILESERVER_PORT=8081

# Detect architecture
ARCH=$(detect_architecture "$PLATFORM")

# ============================================================================
# Hauler service management (uses existing hauler-functions.sh)
# ============================================================================

start_hauler_services() {
  print_header "PHASE: Starting Hauler Registry and Fileserver"
  
  # Check if Hauler services are already running
  local k3s_registry_running=false
  local ess_registry_running=false
  local k3s_fileserver_running=false
  local helm_fileserver_running=false
  
  if [ -f "$WORK_DIR/k3s-registry.pid" ] && kill -0 "$(cat "$WORK_DIR/k3s-registry.pid")" 2>/dev/null; then
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$K3S_REGISTRY_PORT/v2/" 2>/dev/null | grep -q "^200$"; then
      print_success "K3s registry already running on port $K3S_REGISTRY_PORT"
      k3s_registry_running=true
    fi
  fi
  
  if [ -f "$WORK_DIR/ess-registry.pid" ] && kill -0 "$(cat "$WORK_DIR/ess-registry.pid")" 2>/dev/null; then
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:$ESS_REGISTRY_PORT/v2/" 2>/dev/null | grep -q "^200$"; then
      print_success "ESS registry already running on port $ESS_REGISTRY_PORT"
      ess_registry_running=true
    fi
  fi
  
  if [ -f "$WORK_DIR/fileserver.pid" ] && kill -0 "$(cat "$WORK_DIR/fileserver.pid")" 2>/dev/null; then
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$K3S_FILESERVER_PORT/" 2>/dev/null)
    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
      print_success "K3s fileserver already running on port $K3S_FILESERVER_PORT"
      k3s_fileserver_running=true
    fi
  fi
  
  if [ -f "$WORK_DIR/helm-fileserver.pid" ] && kill -0 "$(cat "$WORK_DIR/helm-fileserver.pid")" 2>/dev/null; then
    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:$HELM_FILESERVER_PORT/" 2>/dev/null)
    if [ "$http_code" = "200" ] || [ "$http_code" = "301" ] || [ "$http_code" = "302" ]; then
      print_success "Helm fileserver already running on port $HELM_FILESERVER_PORT"
      helm_fileserver_running=true
    fi
  fi
  
  # Only stop and restart services that aren't running
  if [ "$k3s_registry_running" = false ] || [ "$ess_registry_running" = false ] || \
     [ "$k3s_fileserver_running" = false ] || [ "$helm_fileserver_running" = false ]; then
    print_step "Some Hauler services need to be started..."
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
      if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
        print_success "K3s restarted and ready"
        break
      fi
      retries=$((retries + 1))
      sleep 2
    done
  else
    print_success "All Hauler services already running - skipping restart"
    print_step "K3s will not be restarted since registry configuration hasn't changed"
  fi
  
  print_success "All Hauler services are ready"
}

# ============================================================================
# Cleanup functions
# ============================================================================

light_cleanup() {
  print_header "Light Cleanup (Preserving Hauler Stores)"
  
  print_step "Stopping Hauler services..."
  stop_hauler_services
  
  print_step "Uninstalling K3s..."
  if [ -f /usr/local/bin/k3s-uninstall.sh ]; then
    /usr/local/bin/k3s-uninstall.sh
  fi
  
  print_step "Removing temporary files (keeping Hauler stores)..."
  rm -f "$WORK_DIR"/*.pid
  rm -f "$WORK_DIR"/*.log
  rm -rf "$LOG_DIR"
  
  print_success "Light cleanup completed - Hauler stores preserved in $REPO_ROOT/.build"
  print_step "Next run will skip Hauler sync and use existing stores"
}

cleanup() {
  print_header "Full Cleanup"
  
  read -p "Do you want to remove K3s and all test data including Hauler stores? (y/N): " -n 1 -r
  echo
  
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_step "Cleanup cancelled"
    return
  fi
  
  print_step "Stopping Hauler services..."
  stop_hauler_services
  
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

# ============================================================================
# Main workflow
# ============================================================================

run_full_test() {
  print_header "Local Airgap Test for K3s + ESS"
  
  echo "Configuration:"
  echo "  Hauler Version: $HAULER_VERSION"
  echo "  K3s Version: $K3S_VERSION"
  echo "  ESS Chart Version: $ESS_CHART_VERSION"
  echo "  Domain: $DOMAIN"
  echo "  Platform: linux/$ARCH"
  echo ""
  
  # Check if running as root
  check_root || exit 1
  
  # Check prerequisites
  check_prerequisites "full" || exit 1
  
  # Setup directories
  setup_directories "$WORK_DIR" "$LOG_DIR"
  
  # Install Hauler
  install_hauler "$HAULER_VERSION" "$ARCH" || exit 1
  
  # Build Hauler stores
  build_all_hauler_stores "$REPO_ROOT" "$ARCH" "$LOG_DIR" || exit 1
  
  # Configure K3s registries
  configure_k3s_registries "$CONFIG_DIR/k3s-registries.yaml" "$K3S_REGISTRY_PORT" "$ESS_REGISTRY_PORT"
  
  # Install K3s
  install_k3s_from_hauler "$REPO_ROOT" "$K3S_VERSION" "$ARCH" "$WORK_DIR" "$LOG_DIR" "$K3S_FILESERVER_PORT" || exit 1
  
  # Start Hauler services
  start_hauler_services
  
  # Install Helm
  install_helm_from_hauler "$HELM_VERSION" "$ARCH" "$HELM_FILESERVER_PORT" || exit 1
  
  # Deploy ESS
  deploy_ess "$DOMAIN" "$ESS_CHART_VERSION" "$ESS_REGISTRY_PORT" "$CONFIG_DIR" "$LOG_DIR" "$REPO_ROOT" || exit 1
  
  # Validate deployment
  validate_ess_deployment "$DOMAIN" "$K3S_VERSION" "$ESS_CHART_VERSION" "$ARCH"
}

show_help() {
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
}

# Main function
main() {
  case "${1:-run}" in
    run|test)
      run_full_test
      ;;
    light-cleanup|reset)
      check_root || exit 1
      light_cleanup
      ;;
    cleanup|clean|full-cleanup)
      check_root || exit 1
      cleanup
      ;;
    help|--help|-h)
      show_help
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
