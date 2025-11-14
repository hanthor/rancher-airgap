#!/bin/bash
# Validate Helm Values Against Chart Schema
# This script validates Helm values files against their chart schemas
# Usage: ./validate-helm-values.sh <chart-name> <values-file> [chart-version]

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_step() {
  echo -e "${GREEN}▶ $1${NC}"
}

# Check arguments
if [ $# -lt 2 ]; then
  echo "Usage: $0 <chart-name> <values-file> [chart-version]"
  echo ""
  echo "Examples:"
  echo "  $0 oci://localhost:5002/hauler/matrix-stack ess-values.yaml 25.11.0"
  echo "  $0 bitnami/postgresql values.yaml"
  exit 1
fi

CHART_NAME="$1"
VALUES_FILE="$2"
CHART_VERSION="${3:-}"

# Check if values file exists
if [ ! -f "$VALUES_FILE" ]; then
  print_error "Values file not found: $VALUES_FILE"
  exit 1
fi

# Check if helm is installed
if ! command -v helm &> /dev/null; then
  print_error "Helm is not installed. Please install Helm first."
  exit 1
fi

print_step "Validating Helm values file: $VALUES_FILE"
print_step "Against chart: $CHART_NAME"

# Build helm lint command
HELM_CMD="helm lint"

# Add chart name/repo
if [[ "$CHART_NAME" == oci://* ]]; then
  # OCI chart - need to pull first or use show
  HELM_CMD="helm show values $CHART_NAME"
  
  if [ -n "$CHART_VERSION" ]; then
    HELM_CMD="$HELM_CMD --version $CHART_VERSION"
  fi
  
  # Check if registry is insecure (localhost)
  if [[ "$CHART_NAME" == *localhost* ]]; then
    HELM_CMD="$HELM_CMD --plain-http"
  fi
  
  print_step "Fetching chart schema from OCI registry..."
  
  # First, get the default values to compare
  if ! eval "$HELM_CMD" > /tmp/chart-defaults.yaml 2>/dev/null; then
    print_warning "Could not fetch chart defaults (chart may not exist yet)"
  fi
  
  # Now use helm template to validate
  print_step "Validating values by rendering templates..."
  TEMPLATE_CMD="helm template test-release $CHART_NAME --values $VALUES_FILE"
  
  if [ -n "$CHART_VERSION" ]; then
    TEMPLATE_CMD="$TEMPLATE_CMD --version $CHART_VERSION"
  fi
  
  if [[ "$CHART_NAME" == *localhost* ]]; then
    TEMPLATE_CMD="$TEMPLATE_CMD --plain-http"
  fi
  
  if eval "$TEMPLATE_CMD" > /tmp/rendered-templates.yaml 2>&1; then
    print_success "Values file is valid!"
    print_step "Rendered templates saved to: /tmp/rendered-templates.yaml"
    exit 0
  else
    print_error "Values validation failed!"
    print_step "Check template rendering errors above"
    exit 1
  fi
else
  # Regular chart repository
  HELM_CMD="$HELM_CMD $CHART_NAME --values $VALUES_FILE"
  
  if [ -n "$CHART_VERSION" ]; then
    HELM_CMD="$HELM_CMD --version $CHART_VERSION"
  fi
fi

print_step "Running: $HELM_CMD"

# Run validation
if eval "$HELM_CMD"; then
  print_success "Helm values validation passed!"
  exit 0
else
  print_error "Helm values validation failed!"
  exit 1
fi
