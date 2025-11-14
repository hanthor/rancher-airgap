#!/bin/bash
# Image Verification Script for Airgap Testing
# Verifies all Kubernetes pod images are from local sources

set -euo pipefail

NAMESPACE="${1:-ess}"
ALLOWED_REGISTRIES=(
  "host.k3d.internal"
  "localhost"
  "127.0.0.1"
)

echo "======================================="
echo "Image Source Verification"
echo "======================================="
echo "Namespace: $NAMESPACE"
echo "Allowed registries: ${ALLOWED_REGISTRIES[*]}"
echo ""

TOTAL_IMAGES=0
LOCAL_IMAGES=0
EXTERNAL_IMAGES=0

# Function to check if image is from allowed registry
is_local_image() {
  local image="$1"
  
  for registry in "${ALLOWED_REGISTRIES[@]}"; do
    if [[ "$image" == *"$registry"* ]]; then
      return 0
    fi
  done
  
  return 1
}

# Get all images from pods
echo "Checking pod images in namespace: $NAMESPACE"
echo "---"

while IFS= read -r image; do
  TOTAL_IMAGES=$((TOTAL_IMAGES + 1))
  
  if is_local_image "$image"; then
    echo "✅ LOCAL: $image"
    LOCAL_IMAGES=$((LOCAL_IMAGES + 1))
  else
    echo "❌ EXTERNAL: $image"
    EXTERNAL_IMAGES=$((EXTERNAL_IMAGES + 1))
  fi
done < <(kubectl get pods -n "$NAMESPACE" -o json | jq -r '.items[].spec.containers[].image' 2>/dev/null)

# Also check init containers
while IFS= read -r image; do
  TOTAL_IMAGES=$((TOTAL_IMAGES + 1))
  
  if is_local_image "$image"; then
    echo "✅ LOCAL (init): $image"
    LOCAL_IMAGES=$((LOCAL_IMAGES + 1))
  else
    echo "❌ EXTERNAL (init): $image"
    EXTERNAL_IMAGES=$((EXTERNAL_IMAGES + 1))
  fi
done < <(kubectl get pods -n "$NAMESPACE" -o json | jq -r '.items[].spec.initContainers[]?.image' 2>/dev/null | grep -v "^$" || true)

echo ""
echo "======================================="
echo "Summary"
echo "======================================="
echo "Total images: $TOTAL_IMAGES"
echo "Local images: $LOCAL_IMAGES"
echo "External images: $EXTERNAL_IMAGES"
echo ""

if [ "$EXTERNAL_IMAGES" -gt 0 ]; then
  echo "❌ AIRGAP VALIDATION FAILED"
  echo "Found $EXTERNAL_IMAGES images from external sources"
  echo ""
  echo "Action required:"
  echo "1. Add missing images to Hauler manifests"
  echo "2. Rebuild Hauler stores"
  echo "3. Re-run airgap test"
  exit 1
else
  echo "✅ AIRGAP VALIDATION PASSED"
  echo "All images are from local sources"
  exit 0
fi
