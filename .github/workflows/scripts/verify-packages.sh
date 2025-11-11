#!/bin/bash
# OS Package Repository Verification Script
# Validates that all required OS packages are available in the local repository

set -euo pipefail

REPO_DIR="${1:-/tmp/os-repo}"
REQUIRED_PACKAGES=(
  "iptables"
  "container-selinux"
  "libnetfilter_conntrack"
  "libnfnetlink"
  "libnftnl"
  "git"
  "curl"
  "wget"
)

echo "======================================="
echo "OS Package Repository Verification"
echo "======================================="
echo "Repository directory: $REPO_DIR"
echo "Required packages: ${REQUIRED_PACKAGES[*]}"
echo ""

if [ ! -d "$REPO_DIR" ]; then
  echo "❌ Repository directory not found: $REPO_DIR"
  exit 1
fi

TOTAL_PACKAGES=0
FOUND_PACKAGES=0
MISSING_PACKAGES=0

echo "Checking for required packages..."
echo "---"

for package in "${REQUIRED_PACKAGES[@]}"; do
  TOTAL_PACKAGES=$((TOTAL_PACKAGES + 1))
  
  # Check for both .deb and .rpm packages
  if ls "$REPO_DIR"/*"$package"*.{deb,rpm} 2>/dev/null | grep -q .; then
    echo "✅ FOUND: $package"
    FOUND_PACKAGES=$((FOUND_PACKAGES + 1))
  else
    echo "❌ MISSING: $package"
    MISSING_PACKAGES=$((MISSING_PACKAGES + 1))
  fi
done

echo ""
echo "======================================="
echo "Summary"
echo "======================================="
echo "Total required packages: $TOTAL_PACKAGES"
echo "Found packages: $FOUND_PACKAGES"
echo "Missing packages: $MISSING_PACKAGES"
echo ""

# List all packages in repository
echo "All packages in repository:"
ls -1 "$REPO_DIR"/*.{deb,rpm} 2>/dev/null | while read -r pkg; do
  echo "  - $(basename "$pkg")"
done || echo "  (none)"

echo ""

if [ "$MISSING_PACKAGES" -gt 0 ]; then
  echo "⚠️  WARNING: Missing $MISSING_PACKAGES required packages"
  echo ""
  echo "Action required:"
  echo "1. Download missing packages on connected server"
  echo "2. Add to OS repository"
  echo "3. Recreate repository metadata"
  exit 1
else
  echo "✅ All required packages available"
  exit 0
fi
